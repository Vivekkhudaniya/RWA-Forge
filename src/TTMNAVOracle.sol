// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract TTMNAVOracle is AccessControl {
    bytes32 public constant VALUER_ROLE = keccak256("VALUER_ROLE");

    struct Valuation {
        uint256 propertyValue;
        uint256 rentalIncome;
        uint256 liabilities;
        uint256 totalSupply;
        uint256 timestamp;
        string  ipfsHash;
    }

    Valuation public current;
    Valuation public pending;
    uint256   public timelockEnd;

    uint256 public constant TIMELOCK    = 48 hours;
    uint256 public constant MAX_CHANGE  = 2000;     // 20% circuit breaker (basis points)
    uint256 public constant STALE_LIMIT = 100 days;

    event ValuationProposed(uint256 value, uint256 timelockEnd);
    event ValuationAccepted(uint256 value);

    constructor(address valuer) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VALUER_ROLE, valuer);
    }

    function proposeValuation(
        uint256 propertyValue,
        uint256 rentalIncome,
        uint256 liabilities,
        uint256 totalSupply,
        string calldata ipfsHash
    ) external onlyRole(VALUER_ROLE) {
        if (current.propertyValue > 0) {
            uint256 change = propertyValue > current.propertyValue
                ? ((propertyValue - current.propertyValue) * 10000) / current.propertyValue
                : ((current.propertyValue - propertyValue) * 10000) / current.propertyValue;
            require(change <= MAX_CHANGE, "Circuit breaker triggered");
        }

        pending = Valuation(
            propertyValue,
            rentalIncome,
            liabilities,
            totalSupply,
            block.timestamp,
            ipfsHash
        );
        timelockEnd = block.timestamp + TIMELOCK;
        emit ValuationProposed(propertyValue, timelockEnd);
    }

    // Anyone can execute after timelock expires
    function acceptValuation() external {
        require(block.timestamp >= timelockEnd, "Timelock active");
        require(pending.propertyValue > 0, "No pending valuation");
        current = pending;
        delete pending;
        emit ValuationAccepted(current.propertyValue);
    }

    function getNAVPerToken() external view returns (uint256) {
        require(current.propertyValue > 0, "No valuation set");
        require(
            block.timestamp - current.timestamp <= STALE_LIMIT,
            "NAV is stale"
        );
        // Multiply by 1e18 first so result is scaled (rupees-per-token in 18-decimal form)
        return (current.propertyValue - current.liabilities) * 1e18 / current.totalSupply;
    }
}
