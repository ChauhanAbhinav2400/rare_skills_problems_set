//SPDX-License-Identifier : MIT
pragma solidity ^0.8.28;

interface IERC20 {

function transfer(address to , uint256 amount) external returns(bool);
function approve(address spender , uint256 amount) external returns(bool);
function transferFrom(address from , address to , uint256 amount) external returns(bool);
function balanceOf(address account) external view returns(uint256);
function totalSupply() external view returns(uint256);
function allowance(address owner, address spender) external view returns(uint256);
function name() external view returns(string memory);
function symbol() external view  returns(string memory);
function decimals() external view returns(uint8) ;

}

contract ERC20 is IERC20 {

//metadata storage 
string private _name;
string private _symbol;
uint8 private _decimals;

// token storage 
uint256 public totalSupply;
address public owner;
mapping(address => uint256) private _balances;
mapping(address => mapping(address => uint256)) private _allowances;


// Errors
error ZeroAddress();
error NotOwner();
error InsufficientBalance();

// Events
event Transfer(address  indexed from , address indexed to , uint256 amount);
event Approval(address indexed owner , address indexed spender , uint256 amount);


//construtor 

constructor(string memory name , string memory symbol, uint8 decimals )  {
    _name = name;
    _symbol = symbol;
    _decimals = decimals;
    owner = msg.sender;
    }

// modifier 
modifier isValidAddress(address addr) {
    if(addr == address(0)) revert ZeroAddress();
    _;
}

modifier onlyOwner() {
    if(msg.sender != owner) revert NotOwner();
    _;
}


function transfer(address to , uint256 amount) isValidAddress(to) public returns (bool){
_transfer(msg.sender,to,amount);
return true;
}

function approve(address spender , uint256 amount) isValidAddress(spender) public returns(bool){
    _allowances[msg.sender][spender] = amount;
    emit Approval(msg.sender,spender,amount);
    return true ;
} 

function transferFrom(address from , address to , uint256 amount)  isValidAddress(from) isValidAddress(to) public returns (bool){
    uint256 allowed = _allowances[from][msg.sender] ;
    require(amount <= allowed , "amount should be less than allowed allowance");
    unchecked{
    _allowances[from][msg.sender] -= amount;
    }
    _transfer(from,to,amount);
    return true ;
}

// view functions

function balanceOf(address account) isValidAddress(account)  public view returns(uint256){  
return _balances[account];
}   

function allowance(address _owner, address spender) isValidAddress(_owner) isValidAddress(spender)  public view returns (uint256){  
return _allowances[_owner][spender];
}

// Metadata functions 

function name() public view returns(string memory){
return _name;
}

function symbol() public view returns (string memory){
return _symbol;
}

function decimals() public view returns (uint8){
return _decimals;
}

// Internal Functions

function _transfer(address from , address to , uint256 amount) internal {
require(_balances[from] >= amount,  InsufficientBalance());  
unchecked{
_balances[from] -= amount;
_balances[to] += amount;
}
emit Transfer(from,to,amount);
}

function _mint(address to , uint256 amount) isValidAddress(to) internal onlyOwner {
    unchecked{
    _balances[to] += amount;
    totalSupply += amount;
    }
    emit Transfer(address(0), to , amount);
}

function _burn(address from , uint256 amount) isValidAddress(from) onlyOwner internal {
require(_balances[from] >= amount, "NOT_ENOUGH_BALANCE_TO_BURN");
unchecked{
_balances[from] -= amount;
totalSupply -= amount;
}
emit Transfer(from , address(0), amount);

}
}

