// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

interface IA {
    struct Point {
        uint256 x;
        uint256 y;
    }
    function point() external returns (Point memory);
}

contract LowLevelStruct {
    error CallFailed();
    function main(address a) public returns(uint256 x , uint256 y) {
        (bool ok ,bytes memory data ) = a.call(abi.encodeWithSignature("point()")); 
        if(!ok) revert CallFailed();
        (x,y) = abi.decode(data,(uint256, uint256));
    }

    function highlevelreturnstruct(address _ia) public returns(uint256 x , uint256 y)
    {
        IA.Point memory p = IA(_ia).point();
        return (p.x, p.y);
    }
}