// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

interface IA {
    function bar() external returns (uint256);
}

contract LowLevelReturnUint {

    function main(address a) public returns (uint256) {
        (bool ok, bytes memory data) =
            a.call(abi.encodeWithSignature("bar()"));
        if(!ok) return 0;
        return abi.decode(data, (uint256));
        
    }

    function highLevel(address a) public returns (uint256) {
        try IA(a).bar() returns (uint256 n) {
            return n;
        } catch {
            return 0;
        }
    }
}
