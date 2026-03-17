
// SPDX-License-Identifier: CC-BY-NC-SA-4.0



/// ██████╗ ██╗  ██╗ █████╗ ██╗     ██╗     ███████╗███╗   ██╗ ██████╗ ███████╗
/// ██╔════╝██║  ██║██╔══██╗██║     ██║     ██╔════╝████╗  ██║██╔════╝ ██╔════╝
/// ██║     ███████║███████║██║     ██║     █████╗  ██╔██╗ ██║██║  ███╗█████╗  
/// ██║     ██╔══██║██╔══██║██║     ██║     ██╔══╝  ██║╚██╗██║██║   ██║██╔══╝  
/// ╚██████╗██║  ██║██║  ██║███████╗███████╗███████╗██║ ╚████║╚██████╔╝███████╗
/// ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝
                                                                           
///  ██████╗ ██╗  ██╗                                                          
/// ██╔═████╗██║  ██║                                                          
/// ██║██╔██║███████║                                                          
/// ████╔╝██║╚════██║                                                          
/// ╚██████╔╝     ██║                                                          
///  ╚═════╝      ╚═╝                                                          
                                                                           


pragma solidity ^0.8.20;

contract Challenge04 {

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Paused(address account);
    event Unpaused(address account);

    string public name;
    string public symbol;
    uint8 public immutable decimals = 18;
    uint256 private _totalSupply;
    bool public paused;
    address public owner;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;


    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }

    constructor() {
        name = "BuggyToken4";
        symbol = "BUG4";
        owner = msg.sender;
        _mint(msg.sender, 1000000 * 10 ** decimals);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Challenge4: caller is not owner");
        _;
    }

    function pause() public onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(!paused, "Challenge4: transfers paused");
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "Challenge4: transfer to zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= value, "Challenge4: insufficient balance");

        _balances[from] = fromBalance - value;
        _balances[to] += value;
        emit Transfer(from, to, value);
    }

    function _approve(address tokenOwner, address spender, uint256 value) internal {
        require(tokenOwner != address(0), "Challenge4: approve from zero address");
        require(spender != address(0), "Challenge4: approve to zero address");

        _allowances[tokenOwner][spender] = value;
        emit Approval(tokenOwner, spender, value);
    }

    function _spendAllowance(address tokenOwner, address spender, uint256 value) internal {
        uint256 currentAllowance = allowance(tokenOwner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "Challenge4: insufficient allowance");
            _allowances[tokenOwner][spender] = currentAllowance - value;
        }
    }

    function _mint(address account, uint256 value) internal {
        require(account != address(0), "Challenge4: mint to zero address");
        _totalSupply += value;
        _balances[account] += value;
        emit Transfer(address(0), account, value);
    }
}  


// Bug ==================================================
//“The pause mechanism is broken because transferFrom does not check the paused state, allowing token transfers even when the contract is paused.”

// solution 
// we can make modifier and use it in transferFrom function like transfer function
// // add modifier
// modifier whenNotPaused() {
//     require(!paused, "Challenge4: transfers paused");
//     _;
// }