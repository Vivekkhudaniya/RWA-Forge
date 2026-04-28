// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TTMNAVOracle.sol";
import "../src/TTMToken.sol";
import "../src/IdentityRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Testnet-only mock stablecoin
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1_000_000_000e18); // 1 billion for testing
    }
}

contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // 1. Deploy Identity Registry
        IdentityRegistry registry = new IdentityRegistry(deployer);
        console.log("IdentityRegistry:", address(registry));

        // 2. Deploy NAV Oracle (deployer is also valuer on testnet)
        TTMNAVOracle oracle = new TTMNAVOracle(deployer);
        console.log("NAVOracle:", address(oracle));

        // 3. Deploy mock stablecoin (testnet only)
        MockUSDC stablecoin = new MockUSDC();
        console.log("MockUSDC:", address(stablecoin));

        // 4. Deploy Token
        TTMToken token = new TTMToken(
            address(registry),
            address(oracle),
            address(stablecoin)
        );
        console.log("TTMToken:", address(token));

        // 5. Grant deployer AGENT role on token for initial setup
        token.grantRole(token.AGENT_ROLE(), deployer);

        vm.stopBroadcast();

        // Print summary
        console.log("\n=== Deployment Summary ===");
        console.log("Network:          Polygon Amoy Testnet");
        console.log("Deployer:        ", deployer);
        console.log("IdentityRegistry:", address(registry));
        console.log("NAVOracle:       ", address(oracle));
        console.log("MockUSDC:        ", address(stablecoin));
        console.log("TTMToken:        ", address(token));
        console.log("==========================\n");
    }
}
