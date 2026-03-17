
// SPDX-License-Identifier: CC-BY-NC-SA-4.0

pragma solidity ^0.8.20;

contract Challlenge01 {

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    string private _name;
    string private _symbol;
    uint8 private constant _DECIMALS = 18;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    error InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error InvalidSender(address sender);
    error InvalidReceiver(address receiver);
    error InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error InvalidApprover(address approver);
    error InvalidSpender(address spender);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _DECIMALS;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) revert InvalidSender(from);
        if (to == address(0)) revert InvalidReceiver(to);

        uint256 fromBalance = _balances[from];
        if (fromBalance < value) revert InsufficientBalance(from, fromBalance, value);

        _balances[to] += value;
        emit Transfer(from, to, value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        if (owner == address(0)) revert InvalidApprover(owner);
        if (spender == address(0)) revert InvalidSpender(spender);

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) revert InsufficientAllowance(spender, currentAllowance, value);
            unchecked {
                _approve(owner, spender, currentAllowance - value);
            }
        }
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) revert InvalidReceiver(account);
        _totalSupply += value;
        _balances[account] += value;
        emit Transfer(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        if (account == address(0)) revert InvalidSender(account);

        uint256 accountBalance = _balances[account];
        if (accountBalance < value) revert InsufficientBalance(account, accountBalance, value);

        _balances[account] = accountBalance - value;
        _totalSupply -= value;
        emit Transfer(account, address(0), value);
    }
}

// Bug ============
//  in _transfer we did not subract amount  from "from" account 
//  unchecked{
//         _balances[from] = fromBalance - value;
//         }
