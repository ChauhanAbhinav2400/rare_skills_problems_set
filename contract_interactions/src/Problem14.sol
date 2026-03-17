// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

interface IA {
    function baz() external returns (string memory);
}

contract LowLevelReturnString {

    function main(address a) public returns (string memory) {
        (bool ok, bytes memory data) =
            a.call(abi.encodeWithSignature("baz()"));

        if (!ok) return "";

        return abi.decode(data, (string));
    }

    function highLevel(address a) public returns (string memory) {
        try IA(a).baz() returns (string memory s) {
            return s;
        } catch {
            return "";
        }
    }
}
