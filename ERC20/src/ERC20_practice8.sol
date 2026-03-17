// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


contract ERC20 {

    event Transfer ( address from , address to , uint256 value);
    event Approval ( address owner , address spender , uint256 value);

    string public name; 
    string public symbol ;
    uint8 public constant decimals = 18 ;

    uint256 public totalSupply;
    address public owner; 

    mapping(address => uint256 ) public balanceOf;
    mapping(address => mapping(address => uint256 )) public allowance;

    constructor (string memory _name , string memory _symbol , uint256 _intialSupply){
        name = _name;
        symbol = _symbol ;
        owner = msg.sender;
        _mint(owner , _intialSupply * 10 ** uint256(decimals));
    }

    modifier validAddress(address addr ){
        require(addr != address(0) , "ERC20 : zero address");
        _;
    }

    modifier onlyOwner(){
        require(msg.sender == owner , "ERC20 : Not Owner");
        _;
    }


   function transfer(address to , uint256 value) validAddress(to) public returns (bool){
    uint balance = balanceOf[msg.sender];
    require(balance >= value , "ERC20 : transfer amount exceeds balance" );
    balanceOf[msg.sender] -= value ;
    balanceOf[to] += value;
    emit Transfer(msg.sender, to , value);
    return true ;
   }

   function mint(address account , uint256 value ) onlyOwner validAddress(account) public {
    _mint(account , value); 
   }

   function burn(address account , uint256 value ) onlyOwner validAddress(account) public {
    _burn(account , value);
   }

     function transferFrom (address from , address to ,  uint256 value) validAddress(from) validAddress(to) public returns (bool){
     uint256 allowed = allowance[from][msg.sender];
     require(allowed != type(uint256).max , "ERC20 : transfer amount exceeds allowance" );
     require(allowed >= value , "ERC20 : transfer amount exceeds allowance" );
     allowance[from][msg.sender] = allowed - value;

     uint256 frombalance = balanceOf[from];
     require(frombalance >= value , "ERC20 : transfer amount exceeds balance" );
     unchecked {
        balanceOf[from ] = frombalance - value;
        balanceOf[to] += value;
     }
    emit Transfer(from , to , value );
    return true ;
   }
     function approve(address spender , uint256 value) validAddress(spender) public returns (bool){
        allowance[msg.sender][spender]  = value;
        emit Approval(msg.sender , spender , value);
    return true ;
   }

   function _mint(address account  , uint256 value) validAddress(account) internal {
   totalSupply += value ;
   unchecked{
    balanceOf[account] += value;
   }
   emit Transfer(address(0) , account ,value );
   }

   
   function _burn(address account  , uint256 value ) validAddress(account)  internal {
    uint256 balance = balanceOf[account];
    require(balance >= value , "ERC20 : burn amount exceeds balance" );
   totalSupply -= value ;
   unchecked{
    balanceOf[account] -= value;
   }
   emit Transfer(account, address(0) ,value );
   }

}