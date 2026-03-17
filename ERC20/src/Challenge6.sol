// SPDX-License-Identifier: CC-BY-NC-SA-4.0

/// ██████╗ ██╗  ██╗ █████╗ ██╗     ██╗     ███████╗███╗   ██╗ ██████╗ ███████╗
/// ██╔════╝██║  ██║██╔══██╗██║     ██║     ██╔════╝████╗  ██║██╔════╝ ██╔════╝
/// ██║     ███████║███████║██║     ██║     █████╗  ██╔██╗ ██║██║  ███╗█████╗  
/// ██║     ██╔══██║██╔══██║██║     ██║     ██╔══╝  ██║╚██╗██║██║   ██║██╔══╝  
/// ╚██████╗██║  ██║██║  ██║███████╗███████╗███████╗██║ ╚████║╚██████╔╝███████╗
/// ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝
                                                                           
/// ██████╗  ██████╗                                                          
/// ██╔═████╗██╔════╝                                                          
/// ██║██╔██║███████╗                                                          
/// ████╔╝██║██╔═══██╗                                                         
/// ╚██████╔╝╚██████╔╝                                                         
/// ╚═════╝  ╚═════╝                                                          
                                                                           
pragma solidity ^0.8.20;

contract Challenge06 {
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);

    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
    error Unauthorized();

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    address public contractOwner;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public blacklist;
    uint256 private _totalSupply;

    modifier onlyOwner() {
        if (msg.sender != contractOwner) revert Unauthorized();
        _;
    }

    constructor() {
        name = "BuggyToken6";
        symbol = "BUG6";
        contractOwner = msg.sender;
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function addToBlacklist(address account) public onlyOwner {
        blacklist[account] = true;
        emit Blacklisted(account);
    }

    function removeFromBlacklist(address account) public onlyOwner {
        blacklist[account] = false;
        emit Unblacklisted(account);
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(!blacklist[msg.sender] && !blacklist[to], "Sender or receiver blacklisted");
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(!blacklist[msg.sender] && !blacklist[to], "Sender or receiver blacklisted");
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) revert ERC20InvalidSender(from);
        if (to == address(0)) revert ERC20InvalidReceiver(to);

        uint256 fromBalance = _balances[from];
        if (fromBalance < value) revert ERC20InsufficientBalance(from, fromBalance, value);

        _balances[from] = fromBalance - value;
        _balances[to] += value;
        emit Transfer(from, to, value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        if (owner == address(0)) revert ERC20InvalidApprover(owner);
        if (spender == address(0)) revert ERC20InvalidSpender(spender);

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _spendAllowance(address tokenOwner, address spender, uint256 value) internal {
        uint256 currentAllowance = allowance(tokenOwner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "Challenge06: insufficient allowance");
            _allowances[tokenOwner][spender] = currentAllowance - value;
        }
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) revert ERC20InvalidReceiver(account);
        _totalSupply += value;
        _balances[account] += value;
        emit Transfer(address(0), account, value);
    }
}

//bug ==================================
//  “The blacklist is ineffective because transferFrom does not check whether the from address is blacklisted, allowing blacklisted users’ funds to be transferred via allowances.”
//solution
// require(
//     !blacklist[from] &&
//     !blacklist[msg.sender] &&
//     !blacklist[to],
//     "Sender, spender, or receiver blacklisted"
// );