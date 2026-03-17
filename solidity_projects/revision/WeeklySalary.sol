// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {console} from "forge-std/console.sol";


contract WeeklySalary is Ownable2Step {

    using SafeERC20 for ERC20;
    ERC20 public immutable token;

     struct Contractor {
        uint256 weeklySalary;
        uint256 lastWithdrawal;
     }
    

    event ContractorCreated(address indexed contractor, uint256 weeklySalary);
    event ContractorDeleted(address indexed contractor);
    event Withdrawal(address indexed contractor, uint256 amount);


    mapping(address => Contractor) public contractors;

    error InvalidContractorAddress();
    error InvalidWeeklySalary();
    error ContractorAlreadyExists();
    error InsufficientBalance();
     
    constructor(address token_) Ownable(msg.sender){
        token = ERC20(token_);
    }

    function createContractor(address _contractor , uint256 _weeklySalary) external onlyOwner {
        if(address(0) == _contractor){
            revert InvalidContractorAddress();
        }
        if(_weeklySalary < 0 ) revert InvalidWeeklySalary();
        if(contractors[_contractor].weeklySalary != 0) revert ContractorAlreadyExists();
        contractors[_contractor] = Contractor(
            {
                weeklySalary : _weeklySalary,
                lastWithdrawal : block.timestamp
            }
        );
        emit ContractorCreated(_contractor, _weeklySalary);
    }

    function deleteContractor(address _contractor ) external onlyOwner {
        if(_contractor == address(0)) revert InvalidContractorAddress();
        if(contractors[_contractor].weeklySalary == 0) revert InvalidContractorAddress();
        delete contractors[_contractor];
        emit ContractorDeleted(_contractor);
    } 

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