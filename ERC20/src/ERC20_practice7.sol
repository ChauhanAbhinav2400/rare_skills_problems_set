// SPDX-License_Identifier : MIT 
pragma solidity ^0.8.26;

contract ERC20 {


event Transfer(address indexed  from , address indexed  to , uint256 amount);
event Approval(address indexed owner , address indexed spender , uint256 amount);

string public name;
string public symbol;
uint8  public constant  decimals = 18;
uint256 public totalSupply;
address public owner;

mapping(address => uint256) public balanceOf;
mapping(address => mapping(address => uint256)) public allowance;


constructor (string memory _name , string memory _symbol , uint256 intialSupply) {
    name = _name;
    symbol = _symbol;
    owner = msg.sender;
    _mint(msg.sender , intialSupply  *  10 ** uint256(decimals));
}

error NotOwner();
error InvalidAddress();
error Insufficient_Balance();
error Insufficient_allowance();


modifier onlyOwner () {
    if(msg.sender != owner ) revert NotOwner();
    _;
}

modifier isValidAddress(address addr) {
    if(addr == address(0)) revert InvalidAddress();
    _;

}

function transfer(address to , uint256 amount) external returns(bool){
     if(balanceOf[msg.sender] < amount) revert Insufficient_Balance();
    _transfer(msg.sender,to, amount);
    return true;
}

function transferFrom(address from , address to , uint256 amount) external returns(bool){
    _spendAllowance(from , msg.sender , amount);
    _transfer(from , to , amount);
    return true;
}

function approve(address spender , uint256 amount) external isValidAddress(spender) returns(bool){
    allowance[msg.sender][spender] = amount;
    emit Approval(msg.sender,spender,amount);
    return true;
}

function _transfer(address from , address to , uint256 amount) internal isValidAddress(from) isValidAddress(to) {
uint256 fromBalance = balanceOf[from];
if(fromBalance < amount) revert Insufficient_Balance();
unchecked {
    balanceOf[from] = fromBalance - amount;
    balanceOf[to] += amount;
}
emit Transfer(from , to , amount);
}

function _spendAllowance ( address owner , address spender , uint256 amount) internal isValidAddress(owner) {
    uint256 allowed = allowance[owner][spender];
    if(allowed != type(uint256).max) {
        if(allowed < amount) revert Insufficient_allowance();
        allowance[owner][spender] = allowed - amount;
        }
}

function _mint(address account , uint256 amount) internal isValidAddress(account) {
balanceOf[account] += amount;
unchecked{
    totalSupply += amount;
}
emit Transfer(address(0), account , amount);
}

function _burn(address account, uint256 amount) internal isValidAddress(account) {
    uint256 balance = balanceOf[account];
    if(balance < amount) revert Insufficient_Balance();
    unchecked {
        balanceOf[account] -= amount;
        totalSupply -= amount;
    }
    emit Transfer(account , address(0) , amount);
}


}
