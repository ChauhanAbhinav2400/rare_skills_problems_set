// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// // import {Test, console} from "forge-std/Test.sol";
// // import {Average} from "../src/Average.sol";

// contract AverageTest is Test {
//     Average public a;

//     function setUp() public {
//         a = new Average();
//     }

//     function test_zero() public view {
//         assertEq(a.average(0, 0), 0);
//     }

//     function test_1_1() public view {
//         assertEq(a.average(1, 1), 1);
//     }

//     function test_1_2() public view {
//         assertEq(a.average(1, 2), 1);
//     }

//     function test_2_1() public view {
//         assertEq(a.average(2, 1), 1);
//     }

//     function test_overflow() public {
//         uint256 umaxdiv2 = 57896044618658097711785492504343953926634992332820282019728792003956564819967;
//         assertEq(a.average(umaxdiv2, umaxdiv2), umaxdiv2);
//     }
// }
