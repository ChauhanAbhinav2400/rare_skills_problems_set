// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// If someone wants to sell a token, they create a dutch auction using the linear dutch auction factory.
// In a single transaction, the factory creates the auction and the token is transferred from the user to the auction.
contract LinearDutchAuctionFactory {
    using SafeERC20 for IERC20;
    event AuctionCreated(address indexed auction, address indexed token, uint256 startingPriceEther, uint256 startTime, uint256 duration, uint256 amount, address seller);

    function createAuction(
        IERC20 _token,
        uint256 _startingPriceEther,
        uint256 _startTime,
        uint256 _duration,
        uint256 _amount,
        address _seller
    ) external returns (address) {
        require(address(_token) != address(0), "ZERO_ADDRESS");
        require(_startingPriceEther > 0 , "");
        require(_startTime >= block.timestamp,"");
        require(_duration > 0 ,"");
        require(_seller != address(0), "");

        address auction = address(
            new LinearDutchAuction(
                 IERC20(_token),
                 _startingPriceEther,
                 _startTime,
                 _duration,
                 _seller
            )
        );

         IERC20(_token).safeTransferFrom(_seller , auction , _amount);
         emit AuctionCreated(auction,address(_token),_startingPriceEther,_startTime,_duration,_amount,_seller);
         return auction;
    }
}

// The auction is a contract that sells the token at a decreasing price until the duration is over.
// The price starts at `startingPriceEther` and decreases linearly to 0 over the `duration`.
// Someone can buy the token at the current price by sending ether to the auction.
// The auction will try to refund the user if they send too much ether.
// The contract directly sends the Ether to the `seller` and does not hold any ether.
// If the price goes to zero, anyone can claim the tokens by calling the contract with msg.value = 0
contract LinearDutchAuction {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public immutable startingPriceEther;
    uint256 public immutable startTime;
    uint256 public immutable durationSeconds;
    address public immutable seller;

    bool public sold;

    error AuctionNotStarted();
    error MsgValueInsufficient();
    error SendEtherToSellerFailed();

    /*
     * @notice Constructor
     * @param _token The token to sell
     * @param _startingPriceEther The starting price of the token in Ether
     * @param _startTime The start time of the auction.
     * @param _duration The duration of the auction. In seconds
     * @param _seller The address of the seller
     */
    constructor(
        IERC20 _token,
        uint256 _startingPriceEther,
        uint256 _startTime,
        uint256 _durationSeconds,
        address _seller
    ) {
        token = IERC20(_token);
        startingPriceEther = _startingPriceEther;
        startTime = _startTime;
        durationSeconds = _durationSeconds;
        seller = _seller;
    }

    /*
     * @notice Get the current price of the token
     * @dev Returns 0 if the auction has ended
     * @revert if the auction has not started yet
     * @revert if someone already purchased the token
     * @return the current price of the token in Ether
     */ 
   function currentPrice() public view returns (uint256) {
        if (block.timestamp < startTime) revert AuctionNotStarted();
        if (sold) return 0;

        uint256 elapsed = block.timestamp - startTime;
        if (elapsed >= durationSeconds) {
            return 0;
        }

        uint256 priceDrop = (startingPriceEther * elapsed) / durationSeconds;
        return startingPriceEther - priceDrop;
    }

    /*
     * @notice Buy tokens at the current price
     * @revert if the auction has not started yet
     * @revert if the auction has ended
     * @revert if the user sends too little ether for the current price
     * @revert if sending Ether to the seller fails
     * @dev Will try to refund the user if they send too much ether. If the refund reverts, the transaction still succeeds.
     */
    receive() external payable {
        if (sold) revert MsgValueInsufficient();
        if (block.timestamp < startTime) revert AuctionNotStarted();

        uint256 price = currentPrice();
        if (msg.value < price) revert MsgValueInsufficient();

        sold = true;

        uint256 tokenBalance = token.balanceOf(address(this));
        token.safeTransfer(msg.sender, tokenBalance);

        (bool ok, ) = seller.call{value: price}("");
        if (!ok) revert SendEtherToSellerFailed();

        if (msg.value > price) {
            unchecked {
                payable(msg.sender).call{value: msg.value - price}("");
            }
        }
    }
}
