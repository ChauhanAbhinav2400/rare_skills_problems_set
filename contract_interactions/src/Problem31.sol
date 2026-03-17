// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

interface IRare {
    function rare(uint256) external;
}

contract TryCatchReason {
    function main(address a, uint256 x) public returns (bytes memory) {
        try IRare(a).rare(x) {
            return "";
        } catch Error(string memory reason) {
            return bytes(reason);
        } catch (bytes memory lowLevelReason) {
            return lowLevelReason;
        }
    }
}
