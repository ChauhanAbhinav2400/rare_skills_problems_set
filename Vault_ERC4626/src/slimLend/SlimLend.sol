// SPDX-License-Identifier: BSL-3.0
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPriceFeed} from "./IPriceFeed.sol";

contract SlimLend is ERC20("LPSlimShares", "LPS") {

    using SafeERC20 for IERC20;

    uint256 totalDepositedTokens;
    uint256 totalBorrowedTokens; 
    uint256 lpSharePrice = 1e18;
    uint256 borrowerSharePrice = 1e18;
    uint256 lastUpdateTime = block.timestamp;
    IERC20 immutable assetToken;
    IERC20 immutable collateralToken;
    IPriceFeed immutable priceFeed;

    uint256 constant WAD = 1e18;    
    
    uint256 constant MIN_COLLATERALIZATION_RATIO = 1.5e18;
    uint256 constant LIQUIDATION_THRESHOLD = 1.1e18;
    uint256 constant OPTIMAL_UTILIZATION = 0.95e18;
    uint256 constant KINK_INTEREST_PER_SECOND = 1585489599; // see test for derivation
    uint256 constant MAX_INTEREST_PER_SECOND =  15854895991; // see test for derivation

    error Slippage();
    error InsufficientLiquidity();
    error MinCollateralization();
    error HealthyAccount();
    error InsufficientCollateral();

    event LPDeposit(address indexed user, uint256 amount, uint256 shares);
    event LPRedeem(address indexed user, uint256 shares, uint256 amount);
    event DepositCollateral(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed borrower, uint256 amount);
    event WithdrawCollateral(address indexed user, uint256 amount);

    struct BorrowerInfo {
        uint256 borrowerShares;
        uint256 collateralTokenAmount;
    }

    mapping(address => BorrowerInfo) public borrowerInfo;

    constructor(IERC20 _assetToken, IERC20 _collateralToken, IPriceFeed _priceFeed) {
        assetToken = _assetToken;
        collateralToken = _collateralToken;
        priceFeed = _priceFeed;
    }

    /**
     * @notice Calculate the current utilization of the pool
     * @return The utilization ratio (total borrowed / total deposited) with 18 decimals
     */
    function utilization() public view returns (uint256) {
      if(totalDepositedTokens == 0) {
        return 0;
      }
      return (totalBorrowedTokens *  WAD ) / totalDepositedTokens;
    }

    /*
     * @notice Calculate the current interest rates based on utilization
     * @param _utilization The current utilization ratio with 18 decimals
     * @return borrowerRate The interest rate paid by borrowers with 18 decimals
     * @return lenderRate The interest rate earned by lenders with 18 decimals
     */
    function interestRate(uint256 _utilization) public pure returns (uint256 borrowerRate, uint256 lenderRate) {
       if(_utilization <= OPTIMAL_UTILIZATION) {
        borrowerRate = (_utilization * KINK_INTEREST_PER_SECOND) / OPTIMAL_UTILIZATION;
       }else{
        uint256 excessUtils = _utilization - OPTIMAL_UTILIZATION;
        uint256 remaining = WAD - OPTIMAL_UTILIZATION;
        uint256 extra = (excessUtils * (MAX_INTEREST_PER_SECOND - KINK_INTEREST_PER_SECOND )) / remaining;
        borrowerRate = KINK_INTEREST_PER_SECOND + extra; 
       }
       lenderRate = (borrowerRate * _utilization) / WAD;
    }

    function _updateSharePrices() internal {
     
     uint256 timeElasped = block.timestamp - lastUpdateTime;
     uint256 util = utilization();
     (uint256 borrowerRate , uint256 lenderRate) = interestRate(util);

     // update borrower share price
     borrowerSharePrice = borrowerSharePrice * (WAD + (borrowerRate * timeElasped)) / WAD;

     // update lp share price
     lpSharePrice = lpSharePrice * (WAD +  (lenderRate * timeElasped)) / WAD;

     // update total Borrowed 
     totalBorrowedTokens  = (totalBorrowedTokens * (WAD + (borrowerRate * timeElasped))) / WAD;

     lastUpdateTime = block.timestamp;
    
    }

    /*
     * @notice Deposit asset token to earn interest and receive LP shares
     * @param amount The amount of asset token to deposit
     * @param minSharesOut The minimum amount of LP shares to receive (slippage protection)
     */
    function lpDepositAsset(uint256 amount, uint256 minSharesOut) public {
     

     _updateSharePrices();

     assetToken.safeTransferFrom(msg.sender , address(this),amount);

     uint256 sharesToMint = (amount * WAD) / lpSharePrice;

     if(sharesToMint < minSharesOut){
        revert Slippage();
     }

     _mint(msg.sender,sharesToMint);
     totalDepositedTokens += amount;
     emit LPDeposit(msg.sender, amount, sharesToMint);
    }

    /*
     * @notice Redeem asset token by burning LP shares
     * @param amountShares The amount of LP shares to burn
     * @param minAmountAssetOut The minimum amount of asset token to receive (slippage protection)
     */
    function lpRedeemShares(uint256 amountShares, uint256 minAmountAssetOut) public {
     
        _updateSharePrices();
     uint256 balance = balanceOf(msg.sender);
     require(balance >= amountShares);

     uint256 amountOut = (amountShares * lpSharePrice) / WAD;
     if(amountOut < minAmountAssetOut ) {
        revert Slippage();
     } 
     uint256 availableLiquidity = totalDepositedTokens - totalBorrowedTokens;
       if(amountOut > availableLiquidity) {
        revert("insufficient liquidity");
     }

     _burn(msg.sender,amountShares);
     totalDepositedTokens -= amountOut;
     assetToken.safeTransfer(msg.sender,amountOut);
    
emit LPRedeem(msg.sender, amountShares, amountOut);
     

    }

    /*
     * @notice Deposit collateral token
     * @param amount The amount of collateral token to deposit
     */
    function borrowerDepositCollateral(uint256 amount) public {
    
    collateralToken.safeTransferFrom(msg.sender , address(this),amount);
    borrowerInfo[msg.sender].collateralTokenAmount += amount;
    emit DepositCollateral(msg.sender, amount);
}

    /*
     * @notice Withdraw collateral token. Cannot withdraw if it would cause the borrower's
     *         collateralization ratio to fall below the minimum.
     * @param amount The amount of collateral token to withdraw
     */
    function borrowerWithdrawCollateral(uint256 amount) public {
    require(borrowerInfo[msg.sender].collateralTokenAmount >= amount, "Not enough collateral to withdraw");

   BorrowerInfo storage user = borrowerInfo[msg.sender];
   uint256 debt = (user.borrowerShares * borrowerSharePrice) / WAD;
   uint256 oldCollateralAmount = user.collateralTokenAmount;
    uint256 newCollateralAmount = oldCollateralAmount - amount;
    user.collateralTokenAmount = newCollateralAmount;
    uint256 collateralValueAfter = collateralValue(msg.sender);
    user.collateralTokenAmount = oldCollateralAmount; // revert state change for collateral amount to do the check
    if(debt > 0 && collateralValueAfter > 0) {
     uint256 ratio = (collateralValueAfter * WAD ) / debt;
     if(ratio < MIN_COLLATERALIZATION_RATIO) {
        revert MinCollateralization();
    }
    user.collateralTokenAmount = newCollateralAmount; // update collateral amount after checks
    collateralToken.safeTransfer(msg.sender,amount);
    emit WithdrawCollateral(msg.sender, amount);
    }

    }

    /*
     * @notice Borrow asset token. Assumes collateral has already been deposited
     * @param amount The amount of asset token to borrow
     */
    function borrow(uint256 amount) public {

    }

    /*
     * @notice Calculate the value of a borrower's collateral in asset token
     * @param borrower The address of the borrower to check
     * @return The dollar value of the borrower's collateral in asset token with 18 decimals
     */
    function collateralValue(address borrower) public view returns (uint256) {
       BorrowerInfo memory user = borrowerInfo[borrower];
       (,int256 price,,,) = priceFeed.latestRoundData();
       uint256 decimals = priceFeed.decimals();
       return (user.collateralTokenAmount * uint256(price) ) / (10 ** decimals);
    }

    /*
     * @notice Calculate the collateralization ratio of a borrower
     * @param borrower The address of the borrower to check
     * @return The collateralization ratio (collateral value / debt value) with 18 decimals
     *         If the borrower has no debt, returns type(uint256).max
     */
    function collateralization_ratio(address borrower) public view returns (uint256) {
        return 0; // compilation dummy
    }

    /*
     * @notice Repay borrowed asset token to reduce debt
     * @param amountAsset The amount of asset token to repay
     * @param minBorrowSharesBurned The minimum amount of borrower shares to burn (slippage protection)
     */
    function repay(uint256 amountAsset, uint256 minBorrowSharesBurned) public {
        
    }

    // if x < y return 0, else x - y
    function _subFloorZero(uint256 x, uint256 y) internal pure returns (uint256) {
        return 0; // compilation
    }

    /* 
     * @notice Check if a borrower can be liquidated
     * @param borrower The address of the borrower to check
     * @return True if the borrower can be liquidated, false otherwise
     */
    function canLiquidate(address borrower) public view returns (bool) {
        return false; // compilation
    }

    /*
     * @notice Liquidate a borrower if their collateralization ratio is below the liquidation threshold.
     *         Seize all of the borrower's collateral in exchange for repaying all of their debt.
     *         This liquidation strategy is unsafe because if the debt goes underwater, nobody has an incentive
     *         to liquidate. This is acceptable for a demo / educational project but not for production. 
     * @dev The liquidator must approve the contract to spend the borrower's debt amount in asset token
     * @param borrower The addres vs of the borrower to liquidate
     */
    function liquidate(address borrower) public {
        
    }
}
