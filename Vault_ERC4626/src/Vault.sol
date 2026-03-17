// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vault is ERC20("LPSHARE", "LP") {
    using SafeERC20 for IERC20;

    IERC20 public assetToken;

    event Mint(address indexed from, uint256 amountAsset, uint256 shares);
    event Burn(address indexed from, uint256 amountAsset, uint256 shares);

    error Slippage();

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
    }

    /*
     * @dev burn amountShares from msg.sender, transfer out amount asset rounding down
     * @param amountShares - amount of shares to burn
     * @param minAssetOut - minimum assets out
     * @revert if computed amount asset out is less than minAssetOut
     */
    function withdraw(uint256 amountShares, uint256 minAssetOut) external {
        // your code here
    }

    /*
     * @dev gives the amount of shares an amount of asset is worth. Rounds down
     * @dev returns 1:1 with input if nothing has been minted
     */
    function convertToShares(uint256 amountAsset) public view returns (uint256) {
        // your code here
    }

    /*
     * @dev gives the amount of asset an amount of shares is worth. Rounds down
     * @dev returns 1:1 if nothing has been minted
     */
    function convertToAssets(uint256 amountShares) public view returns (uint256) {
        // your code here
    }
}
