//SPDX-License-Identifier : MIT
pragma solidity ^0.8.20;

contract ERC20 {

// ERRORS    

error ZERO_ADDRESS();
error INSUFFICIENT_BALANCE();
error INSUFFICIENT_ALLOWANCE();
error NOT_OWNER();
error MAX_SUPPLY_EXCEEDED();

//EVENTS

event Transfer(address indexed from , address indexed to , uint256 value);
event Approval(address indexed owner , address indexed spender , uint256 value);
event OwnerShipTransfered(address indexed preveiousOwner , address indexed newOwner);

//STATE VARIABLES

string public name;
string public symbol;
uint8 public constant decimals = 18;
uint256 public totalSupply;
uint256 public immutable maxSupply;
address public owner;
mapping(address=>uint256 ) public balanceOf;
mapping(address => mapping(address => uint256)) public allowance;

//MODIFIERS

modifier validAddress(address addr) {
    if(addr == address(0)) revert ZERO_ADDRESS();
    _;
}

modifier onlyOwner(){
    if(msg.sender != owner) revert NOT_OWNER();
    _;
}

// CONSTRUCTOR

constructor(string memory _name , string memory _symbol , uint256 intialSupply , uint256 _maxSupply){
    name = _name;
    symbol = _symbol;
    owner = msg.sender;
    maxSupply = _maxSupply *10 ** uint256(decimals);
    _mint(owner , intialSupply * 10 ** uint256(decimals));
}

// EXTERNAL FUNCTIONS

function mint(address account , uint256 value) onlyOwner validAddress(account) external {
    if(totalSupply + value > maxSupply) revert MAX_SUPPLY_EXCEEDED();
    _mint(account , value);
}

function burn(uint256 value ) external {
    _burn(msg.sender , value);
}

function transferOwnership(address newOwner) onlyOwner validAddress(newOwner) external {
   address previousOwner = owner;
   owner = newOwner;
   emit OwnerShipTransfered(previousOwner , newOwner);
}

function transfer(address to , uint256 value) validAddress(to) external returns(bool){
    _transfer(msg.sender , to , value);
    return true;
}

function transferFrom(address from , address to , uint256 value) validAddress(from) validAddress(to) external returns(bool){
    _spendAllowance(from , msg.sender , value);
    _transfer(from , to , value);
    return true;
}

function approve(address spender , uint256 value) validAddress(spender) external returns(bool){
    _approve(msg.sender,spender , value);
    return true;
}

function increaseAllowance(address spender , uint256 addedValue) validAddress(spender) external returns(bool){
    _approve(msg.sender , spender , allowance[msg.sender][spender] + addedValue);
    return true;
}

function decreaseAllowance(address spender , uint256 subtractedValue) validAddress(spender) external returns(bool){
    uint256 currentAllowance = allowance[msg.sender][spender];
    if(currentAllowance < subtractedValue ) revert INSUFFICIENT_ALLOWANCE();
    unchecked{
        _approve(msg.sender , spender , currentAllowance - subtractedValue);
    }
    return true;
}

// INTERNAL FUNCTIONS

function _transfer(address from , address to , uint256 value) internal {
    uint256 fromBalance = balanceOf[from];
    if(fromBalance < value) revert INSUFFICIENT_BALANCE();
    unchecked{
    balanceOf[from] = fromBalance - value;
    balanceOf[to] += value;
    }
    emit Transfer(from , to , value);
}

function _spendAllowance(address _owner , address spender , uint256 value) internal {
    uint256 allowed = allowance[_owner][spender];
    if(allowed != type(uint256).max){
        if(allowed < value) revert INSUFFICIENT_ALLOWANCE();
        allowance[_owner][spender] = allowed - value;
    }
}

function _approve(address _owner , address spender , uint256 value) internal {
    allowance[_owner][spender] = value;
    emit Approval(_owner , spender , value);
}

function _mint(address account , uint256 value ) internal validAddress(account) {
    totalSupply += value;
    unchecked {
        balanceOf[account] += value;
    }
    emit Transfer(address(0) , account , value);
}


function _burn(address account , uint256 value ) internal validAddress(account) {
    uint256 accountBalance = balanceOf[account];
    if(accountBalance < value) revert INSUFFICIENT_BALANCE();
    unchecked {
        balanceOf[account] = accountBalance - value;
        totalSupply -= value;
    }
    emit Transfer(account , address(0) , value);
}


}
