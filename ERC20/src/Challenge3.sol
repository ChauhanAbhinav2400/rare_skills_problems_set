// SPDX-License-Identifier: CC-BY-NC-SA-4.0

/// ██████╗ ██╗  ██╗ █████╗ ██╗     ██╗     ███████╗███╗   ██╗ ██████╗ ███████╗
/// ██╔════╝██║  ██║██╔══██╗██║     ██║     ██╔════╝████╗  ██║██╔════╝ ██╔════╝
/// ██║     ███████║███████║██║     ██║     █████╗  ██╔██╗ ██║██║  ███╗█████╗  
/// ██║     ██╔══██║██╔══██║██║     ██║     ██╔══╝  ██║╚██╗██║██║   ██║██╔══╝  
/// ╚██████╗██║  ██║██║  ██║███████╗███████╗███████╗██║ ╚████║╚██████╔╝███████╗
/// ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝
                                                                           
/// ██████╗ ██████╗                                                           
/// ██╔═████╗╚════██╗                                                          
/// ██║██╔██║ █████╔╝                                                          
/// ████╔╝██║ ╚═══██╗                                                          
/// ╚██████╔╝██████╔╝                                                          
/// ╚═════╝ ╚═════╝                                                           
                                                                           


pragma solidity >=0.8.0;

contract Challenge03 {

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor() {
        name = "BuggyToken3";
        symbol = "BUG3";
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function burn(address account, uint256 value) public {
        require(account != address(0), "Invalid burner");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= value, "Insufficient balance");

        _balances[account] = accountBalance - value;
        _totalSupply -= value;
        emit Transfer(account, address(0), value);
    }

    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

     function _spendAllowance(address tokenOwner, address spender, uint256 value) internal {
        uint256 currentAllowance = allowance(tokenOwner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "Challenge3: insufficient allowance");
            _allowances[tokenOwner][spender] = currentAllowance - value;
        }
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "Invalid receiver");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= value, "Insufficient balance");

        _balances[from] = fromBalance - value;
        _balances[to] += value;
        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        _balances[account] += value;
        _totalSupply += value;
        emit Transfer(address(0), account, value);
    }
}


// bug 

// The burn function is publicly callable and allows arbitrary burning of any user’s tokens without authorization,
//  enabling griefing attacks and permanent fund destruction