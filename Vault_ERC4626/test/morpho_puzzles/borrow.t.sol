// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";

import { Borrow } from "../../src/morpho_puzzles/Borrow.sol";
import { IMorpho, MarketParams, Id, Position } from "morpho-blue/src/interfaces/IMorpho.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MorphoBalancesLib } from "morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import { MarketParamsLib } from "morpho-blue/src/libraries/MarketParamsLib.sol";

contract BorrowTest is Test {

    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    // Morpho Blue core contract address
    IMorpho constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

    // WETH contract address on mainnet
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    
    // USDT contract address on mainnet
    IERC20 constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    Borrow borrow;
    MarketParams marketParams;

    function setUp() public {
        // Fork Ethereum mainnet
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        // Define a real Morpho Blue market (WETH collateral, USDT loan)
        marketParams = MarketParams({
            loanToken: address(USDT),
            collateralToken: address(WETH),
            oracle: 0xe9eE579684716c7Bb837224F4c7BeEfA4f1F3d7f,
            irm: 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC,
            lltv: 915000000000000000 // 91.5% LLTV
        });

        // Deploy the puzzle contract
        borrow = new Borrow(MORPHO, marketParams);

        // Mint 10 WETH directly to the borrow contract
        // This is more robust than relying on whale addresses
        deal(address(WETH), address(borrow), 10 ether);
        
        // Verify the contract has the expected starting balance
        assertEq(WETH.balanceOf(address(borrow)), 10 ether, "Initial WETH balance incorrect");
    }

    function testAddCollateralAndBorrow() public {
        uint256 collateralAmount = 5 ether;
        uint256 borrowAmount = 1_000e6; // 1,000 USDT
        
        // Record initial balances
        uint256 initialWETH = WETH.balanceOf(address(borrow));
        uint256 initialUSDT = USDT.balanceOf(address(borrow));
        uint256 initialDebt = MORPHO.expectedBorrowAssets(marketParams, address(borrow));

        // Execute puzzle logic
        borrow.addCollateralAndBorrow(collateralAmount, borrowAmount);

        // Verify borrow position was created
        uint256 finalDebt = MORPHO.expectedBorrowAssets(marketParams, address(borrow));
        assertGt(finalDebt, initialDebt, "Borrow position not created");
        assertGe(finalDebt, borrowAmount, "Debt should be at least the borrowed amount");

        // Verify WETH collateral was deposited
        uint256 finalWETH = WETH.balanceOf(address(borrow));
        assertEq(finalWETH, initialWETH - collateralAmount, "WETH collateral not deposited");

        // Verify USDT was borrowed and received
        uint256 finalUSDT = USDT.balanceOf(address(borrow));
        assertEq(finalUSDT, initialUSDT + borrowAmount, "USDT not received");
        
        // Verify collateral is locked in Morpho using position()
        Id marketId = marketParams.id();
        Position memory position = MORPHO.position(marketId, address(borrow));
        assertEq(position.collateral, collateralAmount, "Collateral not locked in Morpho");
    }

    function testBorrowWithFullCollateral() public {
        uint256 collateralAmount = 10 ether; // Use all available WETH
        uint256 borrowAmount = 2_000e6; // 2,000 USDT

        // Execute puzzle logic
        borrow.addCollateralAndBorrow(collateralAmount, borrowAmount);

        // Verify all WETH was used as collateral
        assertEq(WETH.balanceOf(address(borrow)), 0, "All WETH should be used as collateral");

        // Verify borrow position exists
        uint256 debt = MORPHO.expectedBorrowAssets(marketParams, address(borrow));
        assertGt(debt, 0, "Borrow position not created");

        // Verify USDT was received
        assertGe(USDT.balanceOf(address(borrow)), borrowAmount, "USDT not received");
    }

    function testCollateralTracking() public {
        uint256 collateralAmount = 3 ether;
        uint256 borrowAmount = 500e6;

        borrow.addCollateralAndBorrow(collateralAmount, borrowAmount);

        // Verify the exact collateral amount is tracked in Morpho
        Id marketId = marketParams.id();
        Position memory position = MORPHO.position(marketId, address(borrow));
        assertEq(
            position.collateral,
            collateralAmount,
            "Collateral amount mismatch in Morpho"
        );
    }
}