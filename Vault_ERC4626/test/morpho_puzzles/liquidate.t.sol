// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import { Liquidate } from "../src/Liquidate.sol";
import { IMorpho, MarketParams, Id, Position } from "morpho-blue/src/interfaces/IMorpho.sol";
import { MarketParamsLib } from "morpho-blue/src/libraries/MarketParamsLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// -----------------------------------------------------------------------
/// Mock Oracle (Allows us to control the price)
/// -----------------------------------------------------------------------
contract MockOracle {
    uint256 public price;

    function setPrice(uint256 newPrice) external {
        price = newPrice;
    }
}

contract LiquidateTest is Test {
    using MarketParamsLib for MarketParams;

    // ---------------------------------------------------------------------
    // Mainnet contracts Address
    // ---------------------------------------------------------------------
    IMorpho constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // ---------------------------------------------------------------------
    // Test state
    // ---------------------------------------------------------------------
    address borrower;
    Liquidate liquidator;
    MockOracle oracle;
    MarketParams marketParams;

    function setUp() public {
        // 1. Fork Ethereum mainnet
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        // 2. Deploy mock oracle & set healthy price (1 ETH = $2000)
        oracle = new MockOracle();
        oracle.setPrice(2_000e24);

        // 3. Define market params using our MOCK oracle
        marketParams = MarketParams({
            loanToken: address(USDC),
            collateralToken: address(WETH),
            oracle: address(oracle),
            irm: 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC, // Standard IRM
            lltv: 915000000000000000 // 91.5%
        });

        // 4. Create the market
        MORPHO.createMarket(marketParams);

        // 5. Setup LIQUIDITY PROVIDER (address(this))
        // We supply 1M USDC so there is money to borrow
        deal(address(USDC), address(this), 1_000_000e6);
        USDC.approve(address(MORPHO), type(uint256).max);
        MORPHO.supply(marketParams, 1_000_000e6, 0, address(this), "");

        // 6. Setup BORROWER (Simulated User)
        borrower = makeAddr("borrower");
        deal(address(WETH), borrower, 10 ether); // Give them 10 WETH

        // Switch to acting as the borrower
        vm.startPrank(borrower);
        
        // Approve Morpho to take WETH
        WETH.approve(address(MORPHO), type(uint256).max);
        
        // Supply 10 WETH collateral
        MORPHO.supplyCollateral(marketParams, 10 ether, borrower, "");
        
        // Borrow 5,000 USDC
        MORPHO.borrow(marketParams, 5_000e6, 0, borrower, borrower);
        
        vm.stopPrank();

        // 7. Setup LIQUIDATOR (The Puzzle Solution)
        liquidator = new Liquidate(address(MORPHO));
        
        // Give the liquidator 10,000 USDC to repay debt
        // This is more robust than relying on whale addresses
        deal(address(USDC), address(liquidator), 10_000e6);
        
        // Verify initial balance
        assertEq(
            USDC.balanceOf(address(liquidator)),
            10_000e6,
            "Liquidator should start with 10,000 USDC"
        );
    }

    function testLiquidation() public {
        Id marketId = marketParams.id();

        // 1. Record state before liquidation
        Position memory posBefore = MORPHO.position(marketId, borrower);
        uint256 debtSharesBefore = posBefore.borrowShares;
        uint256 collateralBefore = posBefore.collateral;

        uint256 wethBefore = WETH.balanceOf(address(liquidator));
        uint256 usdcBefore = USDC.balanceOf(address(liquidator));
        
        // Verify borrower has debt and collateral
        assertGt(debtSharesBefore, 0, "Borrower should have debt");
        assertGt(collateralBefore, 0, "Borrower should have collateral");
        
        // 2. CRASH THE MARKET 📉
        // Set price to $400. 10 ETH is now worth $4,000.
        // Debt is $5,000. LTV is > 100%. Position is underwater.
        oracle.setPrice(400e24); 

        // 3. Execute Liquidation via the puzzle contract
        uint256 repayAmount = 1_000e6; // Repay 1,000 USDC
        liquidator.liquidatePosition(marketParams, borrower, repayAmount);

        // 4. Record state after liquidation
        Position memory posAfter = MORPHO.position(marketId, borrower);
        uint256 debtSharesAfter = posAfter.borrowShares;
        uint256 collateralAfter = posAfter.collateral;

        uint256 wethAfter = WETH.balanceOf(address(liquidator));
        uint256 usdcAfter = USDC.balanceOf(address(liquidator));

        // 5. Verify liquidation was successful
        
        // Debt should be reduced
        assertLt(
            debtSharesAfter,
            debtSharesBefore,
            "Borrower's debt shares should decrease"
        );
        
        // Collateral should be reduced (seized by liquidator)
        assertLt(
            collateralAfter,
            collateralBefore,
            "Borrower's collateral should decrease"
        );
        
        // Liquidator should receive WETH collateral
        assertGt(
            wethAfter,
            wethBefore,
            "Liquidator should receive WETH collateral"
        );
        
        // Liquidator should have spent USDC to repay debt
        assertLt(
            usdcAfter,
            usdcBefore,
            "Liquidator should have spent USDC"
        );
        
        // Verify USDC was spent (allow for interest accrual)
        uint256 usdcSpent = usdcBefore - usdcAfter;
        assertGt(usdcSpent, 0, "USDC should have been spent");
        assertLe(
            usdcSpent,
            repayAmount + 1000, // Allow some buffer for rounding/interest
            "USDC spent should not exceed repay amount significantly"
        );
    }

    function testPartialLiquidation() public {
        Id marketId = marketParams.id();

        // Crash the market
        oracle.setPrice(400e24);

        // Record initial state
        Position memory posBefore = MORPHO.position(marketId, borrower);
        uint256 debtSharesBefore = posBefore.borrowShares;

        // Liquidate only 500 USDC worth
        liquidator.liquidatePosition(marketParams, borrower, 500e6);

        // Verify partial liquidation
        Position memory posAfter = MORPHO.position(marketId, borrower);
        uint256 debtSharesAfter = posAfter.borrowShares;

        assertLt(debtSharesAfter, debtSharesBefore, "Debt should be reduced");
        assertGt(debtSharesAfter, 0, "Some debt should remain");
        
        // Verify liquidator received collateral
        assertGt(
            WETH.balanceOf(address(liquidator)),
            0,
            "Liquidator should receive collateral"
        );
    }

    function testCannotLiquidateHealthyPosition() public {
        // Price is still healthy ($2000), so liquidation should fail
        
        vm.expectRevert();
        liquidator.liquidatePosition(marketParams, borrower, 1_000e6);
    }
}