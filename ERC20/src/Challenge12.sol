// SPDX-License-Identifier: CC-BY-NC-SA-4.0

/// ██████╗ ██╗  ██╗ █████╗ ██╗     ██╗     ███████╗███╗   ██╗ ██████╗ ███████╗    
/// ██╔════╝██║  ██║██╔══██╗██║     ██║     ██╔════╝████╗  ██║██╔════╝ ██╔════╝    
/// ██║     ███████║███████║██║     ██║     █████╗  ██╔██╗ ██║██║  ███╗█████╗      
/// ██║     ██╔══██║██╔══██║██║     ██║     ██╔══╝  ██║╚██╗██║██║   ██║██╔══╝      
/// ╚██████╗██║  ██║██║  ██║███████╗███████╗███████╗██║ ╚████║╚██████╔╝███████╗    
/// ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝    
                                                                               
///  ██╗██████╗                                                                    
/// ███║╚════██╗                                                                   
/// ╚██║ █████╔╝                                                                   
///  ██║██╔═══╝                                                                    
///  ██║███████╗                                                                   
///  ╚═╝╚══════╝                                                                   
                                                                               
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20
// contract Challenge12 {

//     event Transfer(address indexed from, address indexed to, uint256 amount);

//     event Approval(address indexed owner, address indexed spender, uint256 amount);

//     string public name;

//     string public symbol;

//     uint8 public immutable decimals;

//     uint256 public totalSupply;

//     mapping(address => uint256) public balanceOf;

//     mapping(address => mapping(address => uint256)) public allowance;

//     address public owner;

//     modifier onlyOwner() {
//         require(msg.sender == owner, "Challenge12: caller is not owner");
//         _;
//     }

//     constructor(string memory _name, string memory _symbol, uint8 _decimals) {
//         name = _name;
//         symbol = _symbol;
//         decimals = _decimals;
//         owner = msg.sender;
//     }

//     function approve(address spender, uint256 amount) public virtual returns (bool) {
//         allowance[msg.sender][spender] = amount;

//         emit Approval(msg.sender, spender, amount);

//         return true;
//     }

//     function gift(address to, uint256 amount) public onlyOwner {
//         balanceOf[to] += amount;

//         emit Transfer(address(0), to, amount);
//     }

//     function transfer(address to, uint256 amount) public virtual returns (bool) {
//         balanceOf[msg.sender] -= amount;

//         unchecked {
//             balanceOf[to] += amount;
//         }

//         emit Transfer(msg.sender, to, amount);

//         return true;
//     }

//     function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
//         uint256 allowed = allowance[from][msg.sender]; 

//         if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

//         balanceOf[from] -= amount;
//         balanceOf[to] += amount;

//         emit Transfer(from, to, amount);

//         return true;
//     }

//     function _mint(address to, uint256 amount) internal virtual {
//         totalSupply += amount;

//         unchecked {
//             balanceOf[to] += amount;
//         }

//         emit Transfer(address(0), to, amount);
//     }

//     function _burn(address from, uint256 amount) internal virtual {
//         balanceOf[from] -= amount;

//         unchecked {
//             totalSupply -= amount;
//         }

//         emit Transfer(from, address(0), amount);
//     }
// }

//Bug================================================
// The gift function effectively mints tokens without updating totalSupply, breaking the ERC20 supply invariant and acting as a hidden mint backdoor. Additionally, _burn lacks balance checks

// Solution ====================

contract ERC20 {


event Transfer ( address indexed  from , address indexed  to , uint256  amount );
event Approval ( address indexed  owner  , address indexed  spender , uint256  amount );


string public name ;
string public symbol ;
uint8 public constant decimals = 18;
uint256 public totalSupply;
address public owner ;
mapping(address=> uint256 ) public balanceOf;
mapping(address => mapping(address=> uint256 )) public allowance;

constructor(string memory _name , string memory _symbol , uint256 _intialSupply){
    name = _name;
    symbol = _symbol;
    owner = msg.sender ;
    _mint(msg.sender , _intialSupply * 10 ** uint256(decimals));
}

modifier onlyOwner() {
    require(msg.sender == owner , "ERC20: caller is not owner");
    _;
}

modifier validAddress(address addr) {
    require(addr != address(0) , "ERC20: zero address");
    _;
}

function gift(address to , uint256 amount ) public onlyOwner validAddress(to) {
    balanceOf[to] += amount;
    totalSupply += amount;
    emit Transfer(address(0) , to , amount);
}

function approve(address spender , uint256 amount)  validAddress(spender) public returns(bool)  {
    allowance[msg.sender][spender] = amount;
    emit Approval(msg.sender , spender , amount);
    return true ;
}
 
 function transfer ( address to , uint256 amount) public virtual validAddress(to) returns (bool){
    uint256 senderbalance = balanceOf[msg.sender];
    require(senderbalance >= amount , "ERC20: transfer amount exceeds balance");
    unchecked {
        balanceOf[msg.sender] = senderbalance - amount;
        balanceOf[to] += amount;
    }
    emit Transfer(msg.sender , to , amount);
    return true;

 }


function transferFrom(address from , address to , uint256 amount) public virtual validAddress(from) validAddress(to) returns(bool){
    uint256 allowed = allowance[from][msg.sender];
    if(allowed != type(uint256).max ){
        if(allowed < amount){
            revert("ERC20: insufficient allowance");
        }
        unchecked{
            allowance[from][msg.sender] = allowed - amount;
            
        }
        }
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount , "Insufficient balance");
        
         balanceOf[from] -= amount ;
         balanceOf[to] += amount;
         emit Transfer(from , to , amount);
         return true ;          
   
}

function _mint ( address account , uint256 amount) validAddress(account) internal {
    balanceOf[account] += amount;
    totalSupply += amount;
    emit Transfer(address(0) , account , amount);
}

function _burn (address account , uint256 amount ) internal  validAddress(account) {
    uint256 accountbalance =  balanceOf[account];
    require(accountbalance >= amount , "ERC20: burn amount exceeds balance");
    unchecked {
        balanceOf[account] = accountbalance - amount;
        totalSupply  -= amount ;
        emit Transfer ( account , address(0) , amount );

    }
}

}