// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./TTMNAVOracle.sol";
import "./IdentityRegistry.sol";

// ERC-3643 compliant tokenized real estate — Trump Tower Mumbai
contract TTMToken is ERC20, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    bytes32 public constant AGENT_ROLE  = keccak256("AGENT_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    IdentityRegistry public identityRegistry;
    TTMNAVOracle     public oracle;
    IERC20           public stablecoin;

    uint256 public constant LOCK_UP      = 365 days;
    uint256 public constant MIN_INVEST   = 100e18;
    uint256 public constant MAX_HOLDING  = 10_000_000e18;

    uint256 public undistributedRental;
    mapping(address => uint256) public purchaseTime;

    event Invested(address indexed investor, uint256 stable, uint256 tokens);
    event Redeemed(address indexed investor, uint256 tokens, uint256 stable);
    event RentalDeposited(uint256 amount);
    event RentalClaimed(address indexed investor, uint256 amount);

    constructor(
        address _registry,
        address _oracle,
        address _stablecoin
    ) ERC20("Trump Tower Mumbai Token", "TTMT") {
        identityRegistry = IdentityRegistry(_registry);
        oracle           = TTMNAVOracle(_oracle);
        stablecoin       = IERC20(_stablecoin);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ERC-3643 core — compliance check on every transfer (OZ v5 hook)
    function _update(address from, address to, uint256 value)
        internal override whenNotPaused
    {
        if (from == address(0)) {
            // Minting — only receiver must be KYC verified
            require(identityRegistry.isVerified(to), "Receiver not KYC verified");
        } else if (to != address(0)) {
            // Transfer — both parties checked
            require(identityRegistry.isVerified(from), "Sender not KYC verified");
            require(identityRegistry.isVerified(to),   "Receiver not KYC verified");
            require(
                block.timestamp >= purchaseTime[from] + LOCK_UP,
                "Lock-up period active"
            );
            require(
                balanceOf(to) + value <= MAX_HOLDING,
                "Exceeds max holding limit"
            );
        }
        super._update(from, to, value);
    }

    function invest(uint256 stableAmount) external nonReentrant whenNotPaused {
        require(identityRegistry.isVerified(msg.sender), "Complete KYC first");
        require(stableAmount >= MIN_INVEST, "Below minimum");

        stablecoin.safeTransferFrom(msg.sender, address(this), stableAmount);
        uint256 nav    = oracle.getNAVPerToken();
        uint256 tokens = (stableAmount * 1e18) / nav;
        purchaseTime[msg.sender] = block.timestamp;
        _mint(msg.sender, tokens);
        emit Invested(msg.sender, stableAmount, tokens);
    }

    function depositRental(uint256 amount) external onlyRole(AGENT_ROLE) {
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        undistributedRental += amount;
        emit RentalDeposited(amount);
    }

    function claimRental() external nonReentrant {
        uint256 bal = balanceOf(msg.sender);
        require(bal > 0, "No tokens held");
        uint256 share = (undistributedRental * bal) / totalSupply();
        require(share > 0, "Nothing to claim");
        undistributedRental -= share;
        stablecoin.safeTransfer(msg.sender, share);
        emit RentalClaimed(msg.sender, share);
    }

    function redeem(uint256 tokenAmount) external nonReentrant {
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient balance");
        require(
            block.timestamp >= purchaseTime[msg.sender] + LOCK_UP,
            "Lock-up active"
        );
        uint256 nav    = oracle.getNAVPerToken();
        uint256 stable = (tokenAmount * nav) / 1e18;
        _burn(msg.sender, tokenAmount);
        stablecoin.safeTransfer(msg.sender, stable);
        emit Redeemed(msg.sender, tokenAmount, stable);
    }

    function pause()   external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }
}
