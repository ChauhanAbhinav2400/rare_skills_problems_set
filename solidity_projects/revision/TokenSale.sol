pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract TokenSale is ERC20("TokenSale" , "TS" ) {

uint256 public constant MAX_SUPPLY  = 100_000_000 * 10 ** 10;
uint256 public constant PRICE_PER_UNIT = 0.001 ether / 10 ** 10;
uint8 public reentrant;

modifier noReentrant() {
    if(reentrant == 1){
        revert("No re-Entrancy");
    }
    reentrant = 1; 
    _;
    reentrant = 0 ;
}

error MaxSupplyReached();

function decimals() public pure override returns(uint8) {
    return 10;
}

function buyTokens() public payable noReentrant{
    require(msg.value >= PRICE_PER_UNIT , "Insufficient ether sent");
    uint256 tokensToMint = (msg.value / PRICE_PER_UNIT);

    if(totalSupply() + tokensToMint > MAX_SUPPLY ){
        revert MaxSupplyReached();
    }

    uint256 remainder = msg.value % PRICE_PER_UNIT;
    if(remainder > 0 ){
        (bool ok , ) = payable(msg.sender).call{value:remainder}("");
        require(ok , "Refund Failed");
    }
    _mint(msg.sender , tokensToMint);
}

receive() external payable{
    buyTokens();
}



}