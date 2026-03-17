// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

interface IERC20 {

    function name() view external returns(string memory);
}

contract TryCatchSimple {

function main(IERC20 token) public view returns(string memory){
try token.name() returns (string memory name){
    return name;
}catch {
    return "";
}
}
}