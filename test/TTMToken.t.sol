// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TTMToken.sol";
import "../src/TTMNAVOracle.sol";
import "../src/IdentityRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TTMTokenTest is Test {
    TTMToken         token;
    TTMNAVOracle     oracle;
    IdentityRegistry registry;
    MockERC20        stablecoin;

    address admin    = address(1);
    address investor = address(2);
    address hacker   = address(3);

    function setUp() public {
        vm.startPrank(admin);

        stablecoin = new MockERC20();
        oracle     = new TTMNAVOracle(admin);
        registry   = new IdentityRegistry(admin);
        token      = new TTMToken(address(registry), address(oracle), address(stablecoin));

        // Grant token the AGENT role for on-chain registration
        token.grantRole(token.AGENT_ROLE(), admin);
        token.grantRole(token.PAUSER_ROLE(), admin);

        // Set initial NAV — ₹500 crore property, ₹50 crore liabilities, 5 crore supply
        oracle.proposeValuation(
            500_000_000e18,
            2_000_000e18,
            50_000_000e18,
            5_000_000e18,
            "ipfs://mock"
        );

        // Fast-forward past 48-hour timelock
        vm.warp(block.timestamp + 49 hours);
        oracle.acceptValuation();

        vm.stopPrank();
    }

    // Test 1 — non-KYC user cannot receive tokens
    function test_NonKYCCannotReceiveTokens() public {
        stablecoin.mint(hacker, 1000e18);

        vm.startPrank(hacker);
        stablecoin.approve(address(token), 1000e18);
        vm.expectRevert("Complete KYC first");
        token.invest(1000e18);
        vm.stopPrank();
    }

    // Test 2 — KYC user can invest and receive tokens
    function test_KYCUserCanInvest() public {
        vm.prank(admin);
        registry.registerIdentity(investor, investor, 356); // India

        stablecoin.mint(investor, 10_000e18);

        vm.startPrank(investor);
        stablecoin.approve(address(token), 10_000e18);
        token.invest(10_000e18);
        vm.stopPrank();

        assertGt(token.balanceOf(investor), 0);
    }

    // Test 3 — circuit breaker blocks >20% NAV change
    function test_CircuitBreakerBlocks() public {
        vm.startPrank(admin);
        vm.expectRevert("Circuit breaker triggered");
        oracle.proposeValuation(
            1_000_000_000e18, // 100% increase — should revert
            2_000_000e18,
            50_000_000e18,
            5_000_000e18,
            "ipfs://mock2"
        );
        vm.stopPrank();
    }

    // Test 4 — lock-up prevents transfer within 1 year
    function test_LockUpPreventsTransfer() public {
        address investor2 = address(4);
        vm.startPrank(admin);
        registry.registerIdentity(investor,  investor,  356);
        registry.registerIdentity(investor2, investor2, 356);
        vm.stopPrank();

        stablecoin.mint(investor, 10_000e18);
        vm.startPrank(investor);
        stablecoin.approve(address(token), 10_000e18);
        token.invest(10_000e18);

        vm.expectRevert("Lock-up period active");
        token.transfer(investor2, 100e18);
        vm.stopPrank();
    }

    // Test 5 — rental claim is proportional to token balance
    function test_RentalClaimProportional() public {
        vm.prank(admin);
        registry.registerIdentity(investor, investor, 356);

        stablecoin.mint(investor, 10_000e18);
        vm.startPrank(investor);
        stablecoin.approve(address(token), 10_000e18);
        token.invest(10_000e18);
        vm.stopPrank();

        stablecoin.mint(admin, 2_000_000e18);
        vm.startPrank(admin);
        stablecoin.approve(address(token), 2_000_000e18);
        token.depositRental(2_000_000e18);
        vm.stopPrank();

        uint256 balBefore = stablecoin.balanceOf(investor);
        vm.prank(investor);
        token.claimRental();
        uint256 balAfter = stablecoin.balanceOf(investor);

        assertGt(balAfter, balBefore);
    }

    // Test 6 — lock-up passes and transfer succeeds
    function test_TransferAfterLockUpSucceeds() public {
        address investor2 = address(4);
        vm.startPrank(admin);
        registry.registerIdentity(investor,  investor,  356);
        registry.registerIdentity(investor2, investor2, 356);
        vm.stopPrank();

        stablecoin.mint(investor, 10_000e18);
        vm.startPrank(investor);
        stablecoin.approve(address(token), 10_000e18);
        token.invest(10_000e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 366 days);

        vm.prank(investor);
        token.transfer(investor2, 100e18);

        assertGt(token.balanceOf(investor2), 0);
    }

    // Test 7 — pause blocks all transfers
    function test_PauseBlocksTransfers() public {
        vm.prank(admin);
        registry.registerIdentity(investor, investor, 356);

        stablecoin.mint(investor, 10_000e18);
        vm.startPrank(investor);
        stablecoin.approve(address(token), 10_000e18);
        token.invest(10_000e18);
        vm.stopPrank();

        vm.prank(admin);
        token.pause();

        stablecoin.mint(investor, 1000e18);
        vm.startPrank(investor);
        stablecoin.approve(address(token), 1000e18);
        vm.expectRevert();
        token.invest(1000e18);
        vm.stopPrank();
    }
}
