// SPDX-License-Identifier : MIT
pragma solidity ^0.8.20;

contract ERC20 {

event Transfer(address from , address to , uint256 value);
event Approval(address owner  , address spender , uint256 value);

string public name; 
string public symbol ;
uint8 public constant decimals = 18 ;
uint256 public totalSupply;
address public owner;

mapping(address => uint256) public balanceOf;
mapping(address => mapping(address => uint256)) public allowance;

constructor (string memory _name , string memory _symbol , uint256 _intialSupply){
    name = _name;
    symbol = _symbol ;
    owner = msg.sender;
   _mint(msg.sender , _intialSupply * 10 ** uint256(decimals));
}

modifier validAddress( address addr) {
    require(addr != address(0) , "Invalid Address");
    _;
}

function transfer (address to , uint256 value) public validAddress(to) returns (bool ){
    uint256 frombalance = balanceOf[msg.sender];
    require( frombalance >= value , "ERC20 : transfer amount exceeds balance" );    
    balanceOf[msg.sender] = frombalance - value;
    balanceOf[to] += value;
    emit Transfer(msg.sender , to , value);
    return true; 
}


function transferFrom (address from , address to ,  uint256 value ) validAddress(from)  validAddress(to)  public returns (bool ){
    uint256 allowed = allowance[from][msg.sender];
    if(allowed != type(uint256).max){
        if(allowed < value){
            revert("ERC20 : transfer amount exceeds allowance");
        }
        allowance[from][msg.sender]  = allowed - value;
    }
    uint256 frombalance = balanceOf[from];
    require( frombalance >= value , "ERC20 : transfer amount exceeds balance" );
    unchecked {
        balanceOf[from] =  frombalance - value;
        balanceOf[to] += value;
    }
    emit Transfer(from , to , value);
    return true; 
}

function approve (address spender , uint256 value )public validAddress(spender)  returns (bool ){
    allowance[msg.sender][spender] = value;
    emit Approval(msg.sender , spender , value);    
    return true; 
}

function _mint (address account , uint256 value )internal validAddress(account)  {
    totalSupply += value;
    unchecked {
        balanceOf[account] += value;
    }

}

function _burn (address account , uint256 value ) internal validAddress(account)  {
    uint256 accountbalance = balanceOf[account];
    require( accountbalance >= value , "ERC20 : burn amount exceeds balance" );
    unchecked{
        totalSupply -= value ;
        balanceOf[account] -= value;  
          }

}

}