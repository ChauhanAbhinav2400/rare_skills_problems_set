// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vault is ERC20("LPSHARE", "LP") {
    using SafeERC20 for IERC20;

    IERC20 public assetToken;

    event Mint(address indexed from, uint256 amountAsset, uint256 shares);
    event Burn(address indexed from, uint256 amountAsset, uint256 shares);

    error Slippage();
    error InsufficientBalance();
    constructor(IERC20 _assetToken) {
        assetToken = _assetToken;
    }

    /*
     * @dev transfer amount asset from msg.sender to contract, mint shares per share price
     * @param amount amount of assets to deposit
     * @param minSharesOut minimum shares to receive, revert otherwise 
     * @revert if mint amount is < minSharesOut 
     */
    function deposit(uint256 amountAsset, uint256 minSharesOut) external {
        // your code here
        uint256 totalAssest = assetToken.balanceOf(address(this));
        uint256 totalShares =  totalSupply();
         uint256  sharesToMint;
        if(totalSupply() == 0 ){
        sharesToMint = amountAsset;
        } else {
         sharesToMint = amountAsset * totalShares / totalAssest;
         bool invariant = (amountAsset * totalShares ) >= ( sharesToMint * totalAssest );
         if(!invariant) revert();
        }

        if(sharesToMint < minSharesOut) revert Slippage();
          assetToken.safeTransferFrom(msg.sender, address(this),amountAsset);
          _mint(msg.sender,sharesToMint);
            
            emit Mint(msg.sender,amountAsset,sharesToMint);
       
    }

    /*
     * @dev burn amountShares from msg.sender, transfer out amount asset rounding down
     * @param amountShares - amount of shares to burn
     * @param minAssetOut - minimum assets out
     * @revert if computed amount asset out is less than minAssetOut
     */
    function withdraw(uint256 amountShares, uint256 minAssetOut) external {
        // your code here
        uint256 totalAssest = assetToken.balanceOf(address(this));
        uint256 totalShares =  totalSupply();
        uint256 assestOut = (amountShares * totalAssest) / totalShares;

        if(assestOut < minAssetOut) revert Slippage();
        if(balanceOf(msg.sender) < amountShares ) revert InsufficientBalance();
        bool invariant = (assestOut * totalShares ) <= ( amountShares * totalAssest );
        if(!invariant) revert();
            assetToken.safeTransfer(msg.sender, assestOut);
            _burn(msg.sender, amountShares);
            emit Burn(msg.sender,assestOut , amountShares );
        
    }

    /*
     * @dev gives the amount of shares an amount of asset is worth. Rounds down
     * @dev returns 1:1 with input if nothing has been minted
     */
    function convertToShares(uint256 amountAsset) public view returns (uint256) {
        // your code here
         uint256 totalAssest = assetToken.balanceOf(address(this));
        uint256 totalShares =  totalSupply();
        uint256 sharesToMint;
        if(totalSupply() == 0){
            sharesToMint = amountAssest;
        }

        uint256 sharesToMint = amountAsset / sharePrice;
        return sharesToMint;
    }

    /*
     * @dev gives the amount of asset an amount of shares is worth. Rounds down
     * @dev returns 1:1 if nothing has been minted
     */
    function convertToAssets(uint256 amountShares) public view returns (uint256) {
        // your code here
        if(totalSupply() == 0 ) {
            return amountShares;
        }
        uint256 sharePrice = assetToken.balanceOf(address(this)) / totalSupply();
        uint256 assestOut = amountShares * sharePrice;
        return assestOut;
    }
}
