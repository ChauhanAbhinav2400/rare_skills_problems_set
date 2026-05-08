// SPDX-License-Identifier : MIT 
pragma solidity ^0.8.26;

contract ERC20 {

event Transfer(address from , address to , uint256 amount);
event Approval(address owner , address spender , uint256 amount);

error ZeroAddress();
error InsufficientBalance();
error InsufficientAllowance();
error NotOwner();

string public name; 
string public symbol;
uint8  public constant decimals = 18;
uint256 public  totalSupply;

address public owner;

mapping(address => uint256) public balanceOf;
mapping(address =>mapping(address => uint256)) public allowance;

modifier isValidAddress(address addr) {
if(addr == address(0)){
    revert ZeroAddress();
}
_;
}

modifier isOwner(address addr) {
    if(addr != owner) {
        revert NotOwner();
    }
    _;
}

constructor (string memory _name , string memory _symbol , uint256 intialSupply ){
    name = _name;
    symbol = _symbol;
    owner = msg.sender;
    _mint(msg.sender , intialSupply * (10 ** decimals));
    
}

function mint(address to , uint256 amount) external {
    _mint(to , amount);
}

function burn(address from , uint256 amount) external {
    _burn(from , amount);
}

function transfer(address to , uint256 amount) external isValidAddress(to) returns(bool) {
_transfer(msg.sender, to , amount);
return true;
}

function approve(address spender , uint256 amount) external isValidAddress(spender) returns(bool){
    require(balanceOf[msg.sender] >= amount, InsufficientBalance());
    allowance[msg.sender][spender] = amount;
    emit Approval(msg.sender , spender , amount);
    return true;
}


function transferFrom(address from , address to , uint256 amount) external isValidAddress(from) isValidAddress(to) returns(bool){
_spendAllowance(from , msg.sender , amount);
_transfer(from , to , amount);
return true;

}

function _transfer(address from , address to , uint256 amount) internal {
uint256 fromBalance = balanceOf[from];
if(fromBalance < amount ){
    revert InsufficientBalance();
}
unchecked{
balanceOf[from] = fromBalance - amount;
balanceOf[to] += amount;
}
emit Transfer(from, to , amount);
}


function _spendAllowance(address owner , address spender , uint256 amount) internal {
uint256 currentAllowance = allowance[owner][spender];

if(currentAllowance != type(uint256).max){
    if(currentAllowance < amount){
        revert InsufficientAllowance();
    }
    unchecked {
        allowance[owner][spender] = currentAllowance - amount;
    }
}

}

function _mint ( address account , uint256 amount) internal isValidAddress(account){

balanceOf[account] += amount;
totalSupply += amount;
emit Transfer(address(0), account , amount);

}

function _burn(address account , uint256 amount) internal isValidAddress(account){
uint256 accountBalance = balanceOf[account];
if(accountBalance < amount){
    revert InsufficientBalance();
}
unchecked {
    balanceOf[account] = accountBalance - amount;
    totalSupply -= amount;
}
emit Transfer(account , address(0) , amount);
}






}