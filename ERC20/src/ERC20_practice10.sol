// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ERC20 {

event Transfer(address indexed from , address indexed to , uint256 value);
event Approval(address indexed owner , address indexed spender , uint256 value);

string public name ;
string public symbol ;
uint8 public constant decimals = 18;
uint256 public totalSupply;
address public owner; 

mapping(address => uint256 ) public balanceOf;
mapping(address => mapping(address => uint256)) public allowance;

modifier onlyOwner() {
    require(msg.sender == owner , "Ownable: caller is not the owner");
    _;
}

modifier validAddress(address account){
    require(account != address(0), "ERC20: address is zero");
    _;
}

constructor( string memory _name , string memory _symbol , uint256 intialSupply ) {
    name = _name;
    symbol = _symbol;
    owner = msg.sender;
   _mint(msg.sender , intialSupply * 10 ** decimals);
}

function transfer(address to , uint256 value) public validAddress(to) returns(bool){
    _transfer(msg.sender, to , value);
    return true;
}

function approve(address spender , uint256 value) public validAddress(spender) returns(bool){
    _approve(msg.sender,spender , value);
    return true;
}

function transferFrom(address from , address to , uint256 value) public validAddress(to)  validAddress(from) returns(bool){
    _spendAllowance(from,msg.sender,value);
    _transfer(from,to,value);
    return true;
}

function _transfer(address from , address to , uint256 value ) internal {

    uint256 frombalance = balanceOf[from];
    require(frombalance >= value,  "ERC20: transfer amount exceeds balance");
    balanceOf[from] = frombalance - value;
    balanceOf[to] += value;
    emit Transfer(from,to,value);
}

function _approve(address _owner , address spender , uint256 value) internal {
    allowance[_owner][spender] = value;
    emit Approval(_owner,spender,value);
}

function _spendAllowance(address owner_ , address spender , uint256 value) internal {
    uint256 currenAllowance = allowance[owner_][spender];
    if(currenAllowance != type(uint256).max){
        require(currenAllowance >= value, "ERC20: insufficient allowance");
        _approve(owner_ , spender , currenAllowance - value);
    }
}

function mint(address to , uint256 value) public onlyOwner returns(bool){
    _mint(to,value);
    return true;
}

function burn(address from , uint256 value) public onlyOwner returns(bool){
    _burn(from,value);
    return true;
}


function _mint(address account , uint256 value ) internal validAddress(account) {
    totalSupply += value;
    balanceOf[account] += value;
    emit Transfer(address(0), account , value);
    }



   function _burn (address account , uint256 value ) internal validAddress(account) {
    uint256 accountBalance = balanceOf[account];
    require(accountBalance >= value, "ERC20: burn amount exceeds balance");
    balanceOf[account] = accountBalance - value;
    totalSupply -= value;
    emit Transfer(account , address(0) , value);
   } 
}
