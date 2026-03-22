// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vault is ERC20("LPSHARE", "LP") {
    using SafeERC20 for IERC20;

    IERC20 public assetToken;
    address public dao = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    uint256 lastAssetAmount = 0; 

    event Mint(address indexed from, uint256 amountAsset, uint256 shares);
    event Burn(address indexed from, uint256 amountAsset, uint256 shares);

    error Slippage();

    constructor(IERC20 _assetToken) {
        assetToken = _assetToken;
    }

    function _mintProtocolFeeWrong() internal {
        uint256 currentAssetAmount = assetToken.balanceOf(address(this));
        if (lastAssetAmount != 0 && currentAssetAmount > lastAssetAmount) {
            uint256 profit = currentAssetAmount - lastAssetAmount;
            uint256 fee = profit / 10; // 10% fee
            uint256 sharesToMint = convertToShares(fee);
            _mint(dao, sharesToMint);
        }
    }

    function _mintProtocolFee() internal {
        // your code here
        uint256 currentDeposit = assetToken.balanceOf(address(this));
        if(lastAssetAmount != 0 && currentDeposit > lastAssetAmount){
            uint256 fees = currentDeposit - lastAssetAmount;
            uint256 supply = totalSupply();
           uint256 feeshares = (supply * fees) / (lastAssetAmount + (9 * currentDeposit));
            _mint(dao,feeshares);
        }
    }

    /*
     * @dev transfer amount asset from msg.sender to contract, mint shares per share price
     * @param amount amount of assets to deposit
     * @param minSharesOut minimum shares to receive, revert otherwise 
     * @revert if mint amount is < minSharesOut 
     */
    function deposit(uint256 amountAsset, uint256 minSharesOut) external {
        _mintProtocolFee();
        uint256 amountShares = convertToShares(amountAsset);
        require(amountShares >= minSharesOut, Slippage());
        assetToken.safeTransferFrom(msg.sender, address(this), amountAsset);
        _mint(msg.sender, amountShares);

        lastAssetAmount = assetToken.balanceOf(address(this));
        emit Mint(msg.sender, amountAsset, amountShares);
    }

    /*
     * @dev burn amountShares from msg.sender, transfer out amount asset rounding down
     * @param amountShares - amount of shares to burn
     * @param minAssetOut - minimum assets out
     * @revert if computed amount asset out is less than minAssetOut
     */
    function withdraw(uint256 amountShares, uint256 minAssetOut) external {
        _mintProtocolFee();
        uint256 amountAsset = convertToAssets(amountShares);
        require(amountAsset >= minAssetOut, Slippage());
        assetToken.transfer(msg.sender, amountAsset);
        _burn(msg.sender, amountShares);

        lastAssetAmount = assetToken.balanceOf(address(this));
        emit Burn(msg.sender, amountAsset, amountShares);
    }

    /*
     * @dev gives the amount of shares an amount of asset is worth. Rounds down
     * @dev returns 1:1 with input if nothing has been minted
     */
    function convertToShares(uint256 amountAsset) public view returns (uint256) {
        uint256 balance = assetToken.balanceOf(address(this));
        if (totalSupply() == 0) {
            return amountAsset;
        }
        return amountAsset * totalSupply() / balance;
    }

    /*
     * @dev gives the amount of asset an amount of shares is worth. Rounds down
     * @dev returns 1:1 if nothing has been minted
     */
    function convertToAssets(uint256 amountShares) public view returns (uint256) {
        if (totalSupply() == 0) {
            return amountShares;
        }
        return amountShares * assetToken.balanceOf(address(this)) / totalSupply();
    }
}
