// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TTMNAVOracle.sol";

contract TTMNAVOracleTest is Test {
    TTMNAVOracle oracle;

    address admin  = address(1);
    address valuer = address(2);
    address anyone = address(3);

    function setUp() public {
        vm.prank(admin);
        oracle = new TTMNAVOracle(valuer);
    }

    function test_ProposeAndAcceptValuation() public {
        vm.prank(valuer);
        oracle.proposeValuation(
            500_000_000e18,
            2_000_000e18,
            50_000_000e18,
            5_000_000e18,
            "ipfs://report1"
        );

        vm.warp(block.timestamp + 49 hours);
        oracle.acceptValuation();

        uint256 nav = oracle.getNAVPerToken();
        // (500M - 50M) / 5M = 90 tokens of value
        assertEq(nav, 90e18);
    }

    function test_TimelockPreventsEarlyAccept() public {
        vm.prank(valuer);
        oracle.proposeValuation(500_000_000e18, 2_000_000e18, 50_000_000e18, 5_000_000e18, "ipfs://r");

        vm.expectRevert("Timelock active");
        oracle.acceptValuation();
    }

    function test_AnyoneCanAcceptAfterTimelock() public {
        vm.prank(valuer);
        oracle.proposeValuation(500_000_000e18, 2_000_000e18, 50_000_000e18, 5_000_000e18, "ipfs://r");

        vm.warp(block.timestamp + 49 hours);
        vm.prank(anyone); // not valuer or admin
        oracle.acceptValuation();

        assertGt(oracle.getNAVPerToken(), 0);
    }

    function test_OnlyValuerCanPropose() public {
        vm.prank(anyone);
        vm.expectRevert();
        oracle.proposeValuation(500_000_000e18, 2_000_000e18, 50_000_000e18, 5_000_000e18, "ipfs://r");
    }

    function test_CircuitBreakerAllows19PercentChange() public {
        // Set baseline
        vm.startPrank(valuer);
        oracle.proposeValuation(500_000_000e18, 2_000_000e18, 50_000_000e18, 5_000_000e18, "ipfs://r1");
        vm.warp(block.timestamp + 49 hours);
        oracle.acceptValuation();

        // 19% increase should succeed (just under 20%)
        uint256 newValue = (500_000_000e18 * 119) / 100;
        oracle.proposeValuation(newValue, 2_000_000e18, 50_000_000e18, 5_000_000e18, "ipfs://r2");
        vm.stopPrank();

        vm.warp(block.timestamp + 49 hours);
        oracle.acceptValuation(); // should not revert
    }

    function test_StaleNAVReverts() public {
        vm.prank(valuer);
        oracle.proposeValuation(500_000_000e18, 2_000_000e18, 50_000_000e18, 5_000_000e18, "ipfs://r");
        vm.warp(block.timestamp + 49 hours);
        oracle.acceptValuation();

        // Fast-forward past 100 day stale limit
        vm.warp(block.timestamp + 101 days);
        vm.expectRevert("NAV is stale");
        oracle.getNAVPerToken();
    }
}
