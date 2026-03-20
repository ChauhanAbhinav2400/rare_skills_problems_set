
// SPDX-License-Identifier :MIT 
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";




contract Vault is ERC20, Ownable , ReentrancyGuard {
using SafeERC20 for IERC20;
IERC20 public assestToken;

// States 
uint256 public  internalTotalAssest;
address public protocol;
uint256 public constant virtualShares = 1e6;
uint256 public constant virtualAssest = 1e6;
uint256 public lastUpdatedBlock;
uint256 public cached;

//errors
error Slippage();

//Event 
 event ProtocolChanged(address oldProtocol , address newProtocol);
 event Deposit(address indexed depositor , uint256 assests , uint256 shares);
 event Withdraw(address indexed withdrawer , uint256 assests , uint256 shares);
 event YieldReported(uint256 amount);

// modfier 
modifier onlyProtocol(){
    if(msg.sender != protocol) revert();
    _;
}

modifier checkInvariant() {
    require(virtualShares == virtualAssest, "virtualShares Should equal to virtualAssets");
    _;
}



constructor (
address _assestToken ,
string memory _name ,
string memory _symbol , 
address _protocol 
) 
ERC20(_name , _symbol) 
Ownable(msg.sender) 
{
assestToken = IERC20(_assestToken);
protocol = _protocol;
}

function deposit(uint256 assestAmount , uint256 minShares ) external nonReentrant returns(uint256) {

   assestToken.safeTransferFrom(msg.sender , address(this),assestAmount);
   uint256 shares = _convertToShares(assestAmount);
   if(shares < minShares) revert Slippage();
  
   _mint(msg.sender,shares);
   uint256 usedAssets = _assestForShares(shares);
   internalTotalAssest += usedAssets;
   emit Deposit(msg.sender , usedAssets , shares);
   return shares;
}


function withdraw(uint256 sharesAmount , uint256 minAssests) external  nonReentrant returns(uint256) {
 
   if(balanceOf(msg.sender) <  sharesAmount)  revert();
   uint256 assests = _convertToAssests(sharesAmount);
   if(assests <  minAssests) revert Slippage();
  _burn(msg.sender ,sharesAmount );
  internalTotalAssest -= assests;
  assestToken.safeTransfer(msg.sender , assests);
  
  emit Withdraw(msg.sender, assests, sharesAmount);
  return assests;

}

function reportYield(uint256 amount ) external onlyProtocol {
require(amount > 0 , "NO PROFIT");
uint256 beforeBalance = assestToken.balanceOf(address(this));
assestToken.safeTransferFrom(protocol , address(this),amount);
internalTotalAssest += amount;
uint256 afterbalance = assestToken.balanceOf(address(this));
require(afterbalance >= beforeBalance + amount , "FAKE_YIELD");
emit YieldReported(amount);
}


function getPrice() external returns(uint256 ) {
    if(block.number == lastUpdatedBlock){
        return cached;
    }

    uint256 supply = totalSupply();

    if(supply == 0 ){
        return 1e18;
    }

    cached = internalTotalAssest * 1e18 / supply;
    lastUpdatedBlock = block.number;
    return cached;
} 

function changeProtocol(address newProtocol) external onlyOwner  {
address old = protocol;    
protocol  = newProtocol;
emit ProtocolChanged(old , newProtocol);
}

// internal function 

function _convertToShares( uint256 assestAmount) internal view checkInvariant returns (uint256) {
  require(assestAmount > 0 );

  uint256 supply = totalSupply();

  uint256 shares = (assestAmount *  (supply + virtualShares)) / (internalTotalAssest + virtualAssest);
  require(shares > 0 , "ZERO_SHARES");
  return shares;
} 

function _convertToAssests( uint256 sharesAmount) internal view checkInvariant returns(uint256) {
require(sharesAmount > 0); 
uint256 supply = totalSupply();

uint256 assests = sharesAmount * ( internalTotalAssest + virtualAssest) / (supply + virtualShares);
return assests;

}

function _assestForShares( uint256 sharesAmount) internal view  returns(uint256) { // helps in preventing rounding down value while deposited 
require(sharesAmount > 0); 
uint256 supply = totalSupply();

uint256 assests = sharesAmount * ( internalTotalAssest + virtualAssest) / (supply + virtualShares);
return assests;

}


// view functions 
function totalAssets() external view returns(uint256){
    return internalTotalAssest;
}

// preview functions 
function previewDeposit(uint256 assestAmount) external view  returns(uint256 ){
    return _convertToShares(assestAmount);
}

function previewWithdraw( uint256 sharesAmount ) external view returns(uint256) {
    return _convertToAssests(sharesAmount);
}



function rescue ( address to) external onlyOwner {
    uint256 totalBalance = assestToken.balanceOf(address(this));
     uint256 excess = totalBalance > internalTotalAssest 
    ? totalBalance - internalTotalAssest 
    : 0;

   assestToken.safeTransfer(to, excess);
}
 
}3