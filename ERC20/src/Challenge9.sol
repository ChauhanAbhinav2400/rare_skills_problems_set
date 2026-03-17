// SPDX-License-Identifier: CC-BY-NC-SA-4.0

/// ██████╗ ██╗  ██╗ █████╗ ██╗     ██╗     ███████╗███╗   ██╗ ██████╗ ███████╗
/// ██╔════╝██║  ██║██╔══██╗██║     ██║     ██╔════╝████╗  ██║██╔════╝ ██╔════╝
/// ██║     ███████║███████║██║     ██║     █████╗  ██╔██╗ ██║██║  ███╗█████╗  
/// ██║     ██╔══██║██╔══██║██║     ██║     ██╔══╝  ██║╚██╗██║██║   ██║██╔══╝  
/// ╚██████╗██║  ██║██║  ██║███████╗███████╗███████╗██║ ╚████║╚██████╔╝███████╗
/// ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝
                                                                           
///  ██████╗  █████╗                                                           
/// ██╔═████╗██╔══██╗                                                          
/// ██║██╔██║╚██████║                                                          
/// ████╔╝██║ ╚═══██║                                                          
/// ╚██████╔╝ █████╔╝                                                          
///  ╚═════╝  ╚════╝                                                           
                                                                        
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20
contract Challenge09 {

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    string public name = "BuggyToken9";

    string public symbol = "BUG9";

    uint8 public constant decimals = 18;

    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    constructor() {
        _mint(msg.sender, 1000000 * 10 ** decimals);
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        unchecked {
            _balances[msg.sender] -= amount;
        }
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            _allowances[from][msg.sender] = currentAllowance - amount;
        }

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: insufficient balance");
        _balances[from] = fromBalance - amount;

        _balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function _mint(address account, uint256 amount) internal {
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        _balances[from] -= amount;

        unchecked {
            _totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

// bug ==================================
// “The transfer function performs an unchecked balance subtraction without verifying sufficient balance, allowing underflow and unlimited token minting.”
// solution : add require statement to check sufficient balance before subtraction
// function transfer(address to, uint256 amount) public returns (bool) {
//     uint256 balance = _balances[msg.sender];
//     require(balance >= amount, "ERC20: insufficient balance");

//     unchecked {
//         _balances[msg.sender] = balance - amount;
//     }
//     _balances[to] += amount;

//     emit Transfer(msg.sender, to, amount);
//     return true;
// }
// ==================================