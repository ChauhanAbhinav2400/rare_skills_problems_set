// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

contract SelfCall {
error CallFailed();
bool public success;
function main() public {
(bool ok ,) = address(this).call(abi.encodeWithSignature("me()"));
if(!ok && !success) {
    revert CallFailed();
} 

}

function me() external {
    require(msg.sender == address(this), "not self");
    success = true;
}

}