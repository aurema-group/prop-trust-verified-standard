// SPDX-License-Identifier: MIT
// ==========================================================================
// Prop Trust Verified Standard (PTVS) v1.0 - Forensics Oracle Interface
// Copyright (c) 2026 Aurema Group L.L.C. (Delaware, USA)
// DOI: 10.5281/zenodo.21719175 | SSRN: 7245361
// ==========================================================================

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol"; // Moved to utils in OZ v5

/// @dev Standard ONCHAINID / ERC-735 Identity Interface
interface IIdentity {
    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes calldata _signature,
        bytes calldata _data,
        string calldata _uri
    ) external returns (bytes32);
    
    // ERC-735 Standard: removeClaim requires the bytes32 claimId, not the topic
    function removeClaim(bytes32 _claimId) external returns (bool);
}

/// @title PTVS Claim Injector v1.1 (Forensics Oracle Registry)
/// @notice Injects forensic audit claims and Physical Proof of Reserve (PPoR) into ONCHAINID identities.
/// @author Aurema Group L.L.C. - Forensics Oracle Initiative
/// @dev Acts as a decentralized bulletin board and oracle for PTVS forensic scores.
contract PTVSClaimInjector is Ownable, Pausable {

    // Topic 70710001: Registered Topic for PTVS Forensic Audit Claims
    uint256 public constant PTVS_CLAIM_TOPIC = 70710001;
    uint8   public constant MIN_SCORE = 70; // 0-100 Scale (70 = Circuit Breaker Threshold)

    address public oracleAuthority;

    struct AuditClaim {
        uint8   score;
        bytes32 reportHash;
        uint256 expiryTimestamp;
        string  reportURI;
        bool    exists;
    }

    // Mapping: Asset Identity Address => AuditClaim
    mapping(address => AuditClaim) public claims;

    // --- EVENTS ---
    event ClaimInjected(
        address indexed assetIdentity,
        uint8   score,
        bytes32 indexed reportHash,
        uint256 expiryTimestamp,
        string  reportURI
    );
    
    event ClaimRevoked(
        address indexed assetIdentity,
        bytes32 indexed revokedHash,
        string reason
    );

    event OracleAuthorityUpdated(address indexed previousAuthority, address indexed newAuthority);

    // --- MODIFIERS ---
    modifier onlyOracle() {
        require(msg.sender == oracleAuthority, "PTVS: UNAUTHORIZED_ORACLE");
        _;
    }

    constructor(address _oracleAuthority) Ownable(msg.sender) {
        require(_oracleAuthority != address(0), "PTVS: INVALID_ADDRESS");
        oracleAuthority = _oracleAuthority;
    }

    // --- ADMIN FUNCTIONS ---

    /// @notice Updates the trusted Oracle Signing Authority (e.g., Multisig or Backend API)
    function setOracleAuthority(address _newAuthority) external onlyOwner {
        require(_newAuthority != address(0), "PTVS: INVALID_ADDRESS");
        emit OracleAuthorityUpdated(oracleAuthority, _newAuthority);
        oracleAuthority = _newAuthority;
    }

    // --- CORE ORACLE FUNCTIONS ---

    /// @notice Registers audit claim internally and attempts ONCHAINID injection
    /// @param _identityAddress The ONCHAINID Identity contract address of the tokenized asset
    function injectClaim(
        address _identityAddress,
        uint8   _score,
        bytes32 _reportHash,
        uint256 _expiry,
        string calldata _uri,
        bytes calldata _signature
    ) external onlyOracle whenNotPaused {
        require(_score >= MIN_SCORE, "PTVS: SCORE_BELOW_THRESHOLD");
        require(_expiry > block.timestamp, "PTVS: EXPIRED_CLAIM");
        require(_identityAddress != address(0), "PTVS: INVALID_IDENTITY");

        claims[_identityAddress] = AuditClaim({
            score: _score,
            reportHash: _reportHash,
            expiryTimestamp: _expiry,
            reportURI: _uri,
            exists: true
        });

        // Encode PTVS Data (Score + Hash) for ONCHAINID
        bytes memory claimData = abi.encode(_score, _reportHash);

        // Attempt direct ONCHAINID Claim Injection (Scheme 1: ECDSA)
        // Fails silently if Identity contract lacks permissions, keeping the PTVS Registry updated regardless.
        if (_signature.length > 0 && _identityAddress.code.length > 0) {
            try IIdentity(_identityAddress).addClaim(
                PTVS_CLAIM_TOPIC,
                1, // Scheme 1 = ECDSA Signature
                address(this),
                _signature,
                claimData,
                _uri
            ) {} catch {
                // Graceful fallback: Claim is stored in PTVS Registry even if ONCHAINID push fails.
            }
        }

        emit ClaimInjected(_identityAddress, _score, _reportHash, _expiry, _uri);
    }

    /// @notice EMERGENCY CIRCUIT BREAKER: Revokes a claim before expiration
    /// @dev Used when physical asset suffers catastrophic damage or legal embargo.
    function revokeClaim(address _identityAddress, string calldata _reason) external onlyOracle whenNotPaused {
        require(claims[_identityAddress].exists, "PTVS: CLAIM_NOT_FOUND");
        
        bytes32 revokedHash = claims[_identityAddress].reportHash;
        delete claims[_identityAddress];

        // Attempt to remove from ONCHAINID if possible
        if (_identityAddress.code.length > 0) {
            // ERC-735 Claim ID is calculated as keccak256(abi.encode(issuer, topic))
            bytes32 claimId = keccak256(abi.encode(address(this), PTVS_CLAIM_TOPIC));
            try IIdentity(_identityAddress).removeClaim(claimId) {} catch {}
        }

        emit ClaimRevoked(_identityAddress, revokedHash, _reason);
    }

    // --- VIEW FUNCTIONS (For ERC-3643 Compliance Modules) ---

    /// @notice Checks if the PTVS Forensic Audit is valid and unexpired
    function isClaimValid(address _identityAddress) external view returns (bool) {
        AuditClaim memory c = claims[_identityAddress];
        return c.exists 
            && c.score >= MIN_SCORE 
            && c.expiryTimestamp > block.timestamp;
    }

    /// @notice Returns full claim data and validity status in a single call (Gas optimized for Compliance contracts)
    function getClaim(address _identityAddress) external view returns (
        uint8 score,
        bytes32 reportHash,
        uint256 expiryTimestamp,
        string memory reportURI,
        bool isValid
    ) {
        AuditClaim memory c = claims[_identityAddress];
        bool valid = c.exists && c.score >= MIN_SCORE && c.expiryTimestamp > block.timestamp;
        return (c.score, c.reportHash, c.expiryTimestamp, c.reportURI, valid);
    }

    // --- EMERGENCY FUNCTIONS ---
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}
