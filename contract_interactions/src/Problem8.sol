// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

contract IsContract {

function iscontract(address addr) view external returns(bool){
    return addr.code.length == 0 ? false : true;
}
}