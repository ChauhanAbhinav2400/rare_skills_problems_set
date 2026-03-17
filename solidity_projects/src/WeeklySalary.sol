// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {console} from "forge-std/console.sol";

// specification
// - the contract is used to pay contractors weekly
// - a contractor can withdraw a fixed salary every week
// - if they do not withdraw for more than a week, they also withdraw undrawn salary
// - Example: less than 1 week withdraw: 0 salary
// -          more than 1 week withdraw, but less than 2 weeks: 1 week salary
// -          more than 2 weeks withdraw, but less than 3 weeks: 2 weeks salary
// -          etc.
// - if a contractor is deleted, they cannot withdraw anymore
// - no partial payments, if the contract doesn't have enough balance, the function will revert
// - with InsufficientBalance()
contract WeeklySalary is Ownable2Step {

    using SafeERC20 for ERC20;

    constructor(address tokenAddress) Ownable(msg.sender) {
        token = ERC20(tokenAddress);
    }

    struct Contractor {
        uint256 weeklySalary;
        uint256 lastWithdrawal;
    }

    mapping(address => Contractor) public contractors;

    ERC20 public immutable token;

    event ContractorCreated(address indexed contractor, uint256 weeklySalary);
    event ContractorDeleted(address indexed contractor);
    event Withdrawal(address indexed contractor, uint256 amount);

    error ContractorAlreadyExists();
    error InvalidContractorAddress();
    error InvalidWeeklySalary();
    error InsufficientBalance();

    function createContractor(address _contractor, uint256 _weeklySalary) external onlyOwner {
        if(address(0) == _contractor){
            revert InvalidContractorAddress();
        }
        if(_weeklySalary == 0 ){
            revert InvalidWeeklySalary();
        }
        if(contractors[_contractor].weeklySalary != 0){
            revert ContractorAlreadyExists(); 
        }
        contractors[_contractor] = Contractor({
            weeklySalary : _weeklySalary,
            lastWithdrawal : block.timestamp
        });
        emit ContractorCreated(_contractor, _weeklySalary);
    }

    function deleteContractor(address _contractor) external onlyOwner {
        if(_contractor == address(0)){
            revert InvalidContractorAddress();
        }
        if(contractors[_contractor].weeklySalary == 0){
            revert InvalidContractorAddress();
        }
        delete contractors[_contractor];
        emit ContractorDeleted(_contractor);

    }

    /*
     * @dev if the balance of the contract is not sufficient, the function will revert
     */
        function withdraw() external {
        if(contractors[msg.sender].weeklySalary == 0 ){
            revert InvalidContractorAddress();
        }
       (uint256 amountToWithdraw , uint256 weeksSinceLastWithdrawal) = calculateAmountToWithdraw(msg.sender);

       if(token.balanceOf(address(this)) < amountToWithdraw){
       revert InsufficientBalance();
       }

       if(weeksSinceLastWithdrawal > 0) {
         contractors[msg.sender].lastWithdrawal += weeksSinceLastWithdrawal * 1 weeks ;
         token.safeTransfer(msg.sender,amountToWithdraw);
          emit Withdrawal(msg.sender, amountToWithdraw);
       } 
      
      
    }

    function calculateAmountToWithdraw(address _contractor) internal view returns(uint256,uint256){
        Contractor memory contractor = contractors[_contractor];
        uint256 timeSinceLastWithdrawal = block.timestamp - contractor.lastWithdrawal;
        uint256 weeksSinceLastWithdrawal = timeSinceLastWithdrawal / 1 weeks;
        return (weeksSinceLastWithdrawal * contractor.weeklySalary,weeksSinceLastWithdrawal);
    }
}
