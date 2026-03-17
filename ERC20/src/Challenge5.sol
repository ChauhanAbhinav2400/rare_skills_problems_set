// SPDX-License-Identifier: MIT

/// ██████╗ ██╗  ██╗ █████╗ ██╗     ██╗     ███████╗███╗   ██╗ ██████╗ ███████╗
/// ██╔════╝██║  ██║██╔══██╗██║     ██║     ██╔════╝████╗  ██║██╔════╝ ██╔════╝
/// ██║     ███████║███████║██║     ██║     █████╗  ██╔██╗ ██║██║  ███╗█████╗  
/// ██║     ██╔══██║██╔══██║██║     ██║     ██╔══╝  ██║╚██╗██║██║   ██║██╔══╝  
/// ╚██████╗██║  ██║██║  ██║███████╗███████╗███████╗██║ ╚████║╚██████╔╝███████╗
/// ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝
                                                                           
/// ██████╗  ███████╗                                                          
/// ██╔═████╗██╔════╝                                                          
/// ██║██╔██║███████╗                                                          
/// ████╔╝██║╚════██║                                                          
/// ╚██████╔╝███████║                                                          
/// ╚═════╝ ╚══════╝                                                          
                                                                           
pragma solidity ^0.8.20;

contract Challenge05 {

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    string public name;
    string public symbol;
    uint8 public immutable decimals = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor() {
        name = "BuggyToken5";
        symbol = "BUG5";
        _mint(msg.sender, 1000000 * 10 ** decimals);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transfer(to, from, value);
        return true;
    }   
    
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "Challenge5: transfer to zero address");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= value, "Challenge5: insufficient balance");

        _balances[from] = fromBalance - value;
        _balances[to] += value;
        emit Transfer(from, to, value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "Challenge5: approve from zero address");
        require(spender != address(0), "Challenge5: approve to zero address");
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _spendAllowance(address tokenOwner, address spender, uint256 value) internal {
        uint256 currentAllowance = allowance(tokenOwner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "Challenge5: insufficient allowance");
            _allowances[tokenOwner][spender] = currentAllowance - value;
        }
    }

    function _mint(address account, uint256 value) internal {
        require(account != address(0), "Challenge5: mint to zero address");
        _totalSupply += value;
        _balances[account] += value;
        emit Transfer(address(0), account, value);
    }
}

//bug ==================================
// In transferFrom function  the parameters 'from' and 'to' are swapped in the _transfer call
// so anyone can transfer tokens from any address to any other address without proper allowance checks  
// solution
// we need to change the line
// _transfer(to, from, value);
// to
// _transfer(from, to, value);
