//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ERC20 {

event Transfer(address from , address to , uint256 value );
event Approval(address owner , address spender, uint256 value);

string public name;
string public symbol;
uint8 public constant decimals = 18;
uint256 private _totalSupply;
address public owner;

mapping(address => uint256) private _balances;
mapping(address => mapping(address => uint256)) private _allowances;

constructor(string memory _name , string memory _symbol , uint256 initialSupply){
    name = _name;
    symbol = _symbol;
    owner = msg.sender;
   _mint(msg.sender , initialSupply * 10 ** uint256(decimals));
}

modifier onlyOwner {
    require(msg.sender == owner , "Not Owner");
    _;
}

modifier validAddress(address addr){
    require(addr != address(0), "ZERO_ADDRESS");
    _;
}

function transfer(address to , uint256 value) public returns(bool){
    address from = msg.sender;
    _transfer(from , to , value);
return true;
}

function transferFrom(address from , address to ,  uint256 value) public returns(bool){
    address spender = msg.sender;
    _spendAllowance(from , spender , value);
    _transfer(from , to , value);
    return true;
}
function approve(address spender , uint256 value) public returns(bool){
    address _owner = msg.sender;
    _approve(_owner , spender , value);
    emit Approval(_owner , spender , value);
    return true;
}


function balanceOf(address account) public view returns(uint256){
    return _balances[account]; 
}

function allowance(address _owner , address spender) public view returns(uint256){
    return _allowances[_owner][spender];
}

function _transfer(address from , address to , uint256 value ) validAddress(to) validAddress(from) internal {
uint256 balance = _balances[from];
require(balance >= value , "ERC20: transfer amount exceeds balance");
unchecked {
_balances[from] = balance - value;
}
_balances[to] += value;
emit Transfer(from , to , value );
}

function _approve(address _owner , address spender , uint256 value) validAddress(_owner) validAddress(spender) internal{
_allowances[_owner][spender] = value;
}

function _spendAllowance(address _owner , address spender , uint256 value ) validAddress(_owner) internal {
uint256 currentAllowance = _allowances[_owner][spender];

if(currentAllowance != type(uint256).max){
    if(currentAllowance < value){
        revert("ERC20: insufficient allowance");
    }
   unchecked{
    _allowances[_owner][spender] = currentAllowance - value;
     }
}
}

function _mint(address account , uint256 value) validAddress(account) internal  {
    _totalSupply += value;
    _balances[account] += value;
    emit Transfer(address(0), account , value);
}
function _burn ( address account , uint256 value ) validAddress(account) internal {
    uint256 balance = _balances[account];
    require(balance >= value , "ERC20: burn amount exceeds balance");
    unchecked {
        _balances[account] = balance - value;
    }
    _totalSupply -= value; 
    emit Transfer(account , address(0) , value);
}

}