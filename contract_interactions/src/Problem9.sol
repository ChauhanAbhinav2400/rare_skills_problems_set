// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

contract IsFirstBitSet {
    function main(bytes32 x) public pure returns (bool) {
        return (x & bytes32(uint256(1))) != 0;
    }
}

// Making a contract over this bitMpas logic to master the bit manipulation in solidity and also to understand how to use bitmaps for permissions in a DAO.
contract DAOPermissions {
//PROPOSE (bit 0)
// VOTE (bit 1)
// EXECUTE (bit 2)
// MINT (bit 3)
// PAUSE (bit 4)

mapping(address => uint256) public permissions;

uint256 constant PROPOSE = 1 << 0 ;
uint256 constant VOTE = 1 << 1 ; 
uint256 constant EXECUTE = 1 << 2 ;
uint256 constant MINT = 1 << 3 ;
uint256 constant PAUSE = 1 << 4 ;

function grantPermission(address user , uint256 permission) external {
require(address != address(0), "Invalid address");
require(permission == PROPOSE || permission == VOTE || permission == EXECUTE || permission == MINT || permission == PAUSE, "Invalid permission");
permissions[user] |= permission;
}

function revokePermission(address user , uint256 permission) external {
require(user != address(0), "Invalid address");
require(permission == PROPOSE || permission == VOTE || permission == EXECUTE || permission == MINT || permission == PAUSE, "Invalid permission");
require((permissions[user] & permission) != 0 , "User does not have this permission");
permissions[user] &= ~permission;
}

function hasPermission(address user , uint256 permission) external view returns(bool) {
    return (permissions[user] & permission) != 0;
}

function propose() external view returns(string memory) {
    require(this.hasPermission(msg.sender, PROPOSE), "You do not have permission to propose");
    return "Proposal created!";
 }

function vote () external view returns(string memory) {
    require(this.hasPermission(msg.sender, VOTE), "You do not have permission to vote");
    return "Vote casted!";
 }

 function execute() external view returns(string memory) {
    require(this.hasPermission(msg.sender, EXECUTE), "You do not have permission to execute");
    return "Action executed!";
 }

 function mint() external view returns(string memory) {
    require(this.hasPermission(msg.sender, MINT), "You do not have permission to mint");
    return "Tokens minted!";
 }


function pause() external view returns(string memory) {
    require(this.hasPermission(msg.sender, PAUSE), "You do not have permission to pause");
    return "Contract paused!";
 }


function grantMultiplePermissions(address user , combinedPermissions) external {
    require(user != address(0), "Invalid address");
    require(combinedPermissions & ~(PROPOSE | VOTE | EXECUTE | MINT | PAUSE) == 0, "Invalid permissions");
    permissions[user] |= combinedPermissions;
}






}
