pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPool {
    function balances(address depositor) external returns(uint256);
    function deposit() external;
}

contract Depositor {
    IERC20 public immutable token;
    using SafeERC20 for IERC20;

    constructor(address _token) {
     token = IERC20(_token);
    }

    function sendTokens(address pool , uint256 amount) external {
        token.safeTransfer(pool , amount);
        IPool(pool).deposit();
    }
}

contract Pool is IPool {
    IERC20 public immutable token;
    uint256 public totalDeposits;
    event Deposit(address indexed depositor, uint256 amount);
    constructor (address _token){
        token = IERC20(_token);
    }
    mapping(address depositor => uint256) public balances;

    function deposit() external {
        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 amount = balanceAfter - totalDeposits;
        balances[msg.sender] += amount;
        totalDeposits = balanceAfter;
        emit Deposit(msg.sender, amount);
    }



}