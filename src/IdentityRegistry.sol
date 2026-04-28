// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract IdentityRegistry is AccessControl {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    struct Identity {
        address onchainId;
        uint16  country;
        bool    verified;
    }

    mapping(address => Identity) private _identities;

    event IdentityRegistered(address indexed wallet, address onchainId, uint16 country);
    event IdentityRevoked(address indexed wallet);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AGENT_ROLE, admin);
    }

    function registerIdentity(
        address wallet,
        address onchainId,
        uint16  country
    ) external onlyRole(AGENT_ROLE) {
        require(wallet != address(0), "Zero address");
        _identities[wallet] = Identity(onchainId, country, true);
        emit IdentityRegistered(wallet, onchainId, country);
    }

    function revokeIdentity(address wallet) external onlyRole(AGENT_ROLE) {
        _identities[wallet].verified = false;
        emit IdentityRevoked(wallet);
    }

    function isVerified(address wallet) external view returns (bool) {
        return _identities[wallet].verified;
    }

    function getIdentity(address wallet) external view returns (address onchainId, uint16 country, bool verified) {
        Identity memory id = _identities[wallet];
        return (id.onchainId, id.country, id.verified);
    }
}
