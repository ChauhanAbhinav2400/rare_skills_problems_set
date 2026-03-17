//SPDX-License-Identifier : MIT
pragma solidity ^0.8.26;

contract  ERC20 {

event Transfer(address indexed from , address indexed to , uint256 amount);
event Approval(address indexed owner , address indexed spender , uint256 amount);

error ZeroAddress();
error InsufficientBalance();
error InsufficientAllowance();
error NotOwner();

address public owner;
string public name; 
string public symbol;
uint8 public constant decimals = 18; 
mapping(address => uint256) public balanceOf;
mapping(address => mapping(address => uint256)) public allowance;
uint256 public totalSupply;

constructor(string memory _name , string memory _symbol,uint256 initialSupply) {
    name = _name ;
    symbol = _symbol;
    owner  = msg.sender; 
    _mint(msg.sender , initialSupply * (10 ** decimals));
}

modifier isValidAddress(address _address) {
    if(_address == address(0)) revert ZeroAddress();
    _;
}

modifier onlyOwner () {
    if(msg.sender != owner) revert NotOwner();
    _;
}


function transfer(address to , uint256 amount) external returns(bool) {
    _transfer(msg.sender,to,amount);
    return true;
} 

function approve( address spender , uint256 amount )external isValidAddress(spender) returns (bool){
    allowance[msg.sender][spender] = amount;
    emit Approval(msg.sender,spender,amount);
    return true ;
}

function transferFrom(address from , address to, uint256 amount) external returns(bool){
    _spendAllowance(from, msg.sender,amount);
    _transfer(from,to,amount);
    return true;
}

function _transfer(address from , address to , uint256 amount) isValidAddress(to) isValidAddress(from) internal {

uint256 fromBalance = balanceOf[from];
if(fromBalance < amount) revert  InsufficientBalance();

balanceOf[from] = fromBalance - amount;
balanceOf[to] += amount;
emit Transfer(from , to , amount);

}


function _spendAllowance(address _owner , address spender, uint256 amount) internal isValidAddress(_owner) isValidAddress(spender) {
uint256 allowed = allowance[_owner][spender];
if(allowed != type(uint256).max) {
if(allowed < amount) revert InsufficientAllowance();
allowance[_owner][spender] = allowed - amount;
}
} 

function _mint(address account , uint256 amount) internal  isValidAddress(account){
balanceOf[account] += amount;
totalSupply += amount;
emit Transfer(address(0) , account , amount);
}


function _burn(address account, uint256 amount) internal isValidAddress(account) {
    uint256 balanceBefore = balanceOf[account];
    if(balanceBefore < amount) revert InsufficientBalance();

    balanceOf[account] = balanceBefore - amount;
    totalSupply -= amount;

    emit Transfer(account, address(0), amount);
} 

}