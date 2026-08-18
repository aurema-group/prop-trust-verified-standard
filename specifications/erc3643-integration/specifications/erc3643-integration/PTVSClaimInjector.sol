// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title PTVSClaimInjector v2.0
 * @author Forensics Oracle Initiative
 * @notice Decentralized Verifiable Claim Injection for PTVS v1.0
 * @dev Replaces v1.0 centralized owner with governance-controlled architecture
 * 
 * Key Changes from v1.0:
 * - NO single owner() - replaced by TimelockController + Gnosis Safe
 * - PTCE authorization requires governance vote (3/5 approval)
 * - emergencyRevokeAll() removed (now requires 5/5 + 7 days)
 * - Dispute resolution mechanism integrated
 * - Transparent governance events
 * 
 * Standard Reference: DOI 10.5281/zenodo.21719175
 * Governance: forensics-oracle.org/governance/
 * License: MIT (Open Standard)
 */
contract PTVSClaimInjectorV2 is EIP712 {
    using ECDSA for bytes32;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // ============ ENUMS & STRUCTS ============

    enum ClaimStatus {
        VERIFIED,      // Score 70-100: Full trading enabled
        CONDITIONAL,   // Score 50-69: Warnings, 25% haircut
        EXPIRED,       // 90+ days without re-audit
        REVOKED,       // Score <50 or serious violation
        DISPUTED       // Under dispute resolution process
    }

    struct VerifiableClaim {
        bytes32 assetId;
        uint8 ptvsScore;
        bytes32 forensicHash;
        uint256 inspectionTimestamp;
        address ptceAddress;
        ClaimStatus status;
        uint256 lastReauditTimestamp;
        uint256 version;
        uint256 injectedAt;
    }

    struct PTCEInfo {
        bool isActive;
        string ptceId;
        string jurisdiction;
        uint256 authorizedAt;
        uint256 authorizedBy;  // Application ID in governance contract
        uint256 totalInspections;
    }

    // ============ CONSTANTS ============

    string public constant STANDARD_VERSION = "PTVS v1.0";
    string public constant STANDARD_DOI = "10.5281/zenodo.21719175";
    string public constant CONTRACT_VERSION = "2.0.0";
    
    uint256 public constant REAUDIT_INTERVAL = 90 days;
    uint8 public constant VERIFIED_THRESHOLD = 70;
    uint8 public constant CONDITIONAL_THRESHOLD = 50;

    bytes32 private constant CLAIM_TYPEHASH = keccak256(
        "VerifiableClaim(bytes32 assetId,uint8 ptvsScore,bytes32 forensicHash,uint256 inspectionTimestamp,address ptceAddress)"
    );

    // ============ STATE VARIABLES ============

    mapping(bytes32 => VerifiableClaim) public claims;
    mapping(address => PTCEInfo) public ptces;
    
    EnumerableSet.Bytes32Set private allClaimIds;
    EnumerableSet.AddressSet private activePTCEs;
    
    uint256 public totalClaimsInjected;
    uint256 public totalReaudits;
    uint256 public totalRevocations;
    uint256 public totalDisputesTriggered;

    // Governance addresses (immutable after deployment)
    address public immutable governance;      // PTVSGovernance contract
    address public immutable timelock;        // PTVSTimelock contract
    address public immutable deployer;        // Original deployer (for reference only, NO power)

    // ============ EVENTS ============

    event ClaimInjected(
        bytes32 indexed assetId,
        uint8 ptvsScore,
        bytes32 indexed forensicHash,
        address indexed ptceAddress,
        uint256 timestamp,
        ClaimStatus status
    );

    event ClaimRenewed(
        bytes32 indexed assetId,
        uint8 newScore,
        bytes32 indexed newForensicHash,
        uint256 timestamp,
        ClaimStatus newStatus,
        uint256 newVersion
    );

    event ClaimRevoked(
        bytes32 indexed assetId,
        string reason,
        uint256 timestamp,
        address indexed revokedBy
    );

    event ClaimExpired(
        bytes32 indexed assetId,
        uint256 expiredAt
    );

    event ClaimDisputed(
        bytes32 indexed assetId,
        uint256 indexed disputeId,
        address indexed claimant,
        uint256 timestamp
    );

    event CircuitBreakerTriggered(
        bytes32 indexed assetId,
        uint8 score,
        string action,
        uint256 timestamp
    );

    event PTCEAuthorized(
        address indexed ptceAddress,
        string ptceId,
        string jurisdiction,
        uint256 applicationId,
        uint256 timestamp
    );

    event PTCERevoked(
        address indexed ptceAddress,
        string reason,
        uint256 timestamp
    );

    // ============ MODIFIERS ============

    modifier onlyActivePTCE() {
        require(ptces[msg.sender].isActive, "PTVS: Not an active PTCE");
        _;
    }

    modifier onlyTimelock() {
        require(msg.sender == timelock, "PTVS: Only timelock can execute");
        _;
    }

    modifier onlyGovernanceOrTimelock() {
        require(
            msg.sender == governance || msg.sender == timelock,
            "PTVS: Only governance or timelock"
        );
        _;
    }

    modifier claimExists(bytes32 assetId) {
        require(claims[assetId].assetId != bytes32(0), "PTVS: Claim does not exist");
        _;
    }

    // ============ CONSTRUCTOR ============

    constructor(
        address governanceAddress,
        address timelockAddress
    ) EIP712("PTVSClaimInjector", "2.0.0") {
        require(governanceAddress != address(0), "PTVS: Invalid governance");
        require(timelockAddress != address(0), "PTVS: Invalid timelock");
        
        governance = governanceAddress;
        timelock = timelockAddress;
        deployer = msg.sender;
        
        // IMPORTANT: deployer is NOT auto-authorized as PTCE
        // All PTCEs must go through governance application process
    }

    // ============ PTCE MANAGEMENT (GOVERNANCE CONTROLLED) ============

    /**
     * @notice Authorize a new PTCE (only via governance + timelock)
     * @dev Called by timelock after governance approval (3/5 votes)
     */
    function authorizePTCE(
        address ptceAddress,
        string calldata ptceId,
        string calldata jurisdiction,
        uint256 applicationId
    ) external onlyTimelock {
        require(ptceAddress != address(0), "PTVS: Invalid address");
        require(!ptces[ptceAddress].isActive, "PTVS: Already active");

        ptces[ptceAddress] = PTCEInfo({
            isActive: true,
            ptceId: ptceId,
            jurisdiction: jurisdiction,
            authorizedAt: block.timestamp,
            authorizedBy: applicationId,
            totalInspections: 0
        });

        activePTCEs.add(ptceAddress);

        emit PTCEAuthorized(ptceAddress, ptceId, jurisdiction, applicationId, block.timestamp);
    }

    /**
     * @notice Revoke a PTCE (only via governance + timelock)
     */
    function revokePTCE(
        address ptceAddress,
        string calldata reason
    ) external onlyTimelock {
        require(ptces[ptceAddress].isActive, "PTVS: Not active");
        
        ptces[ptceAddress].isActive = false;
        activePTCEs.remove(ptceAddress);

        emit PTCERevoked(ptceAddress, reason, block.timestamp);
    }

    // ============ CLAIM INJECTION ============

    /**
     * @notice Injects a new Verifiable Claim on-chain
     * @dev Only callable by active PTCEs authorized via governance
     */
    function injectClaim(
        bytes32 assetId,
        uint8 ptvsScore,
        bytes32 forensicHash,
        uint256 inspectionTimestamp,
        bytes memory ptceSignature
    ) external onlyActivePTCE {
        require(claims[assetId].assetId == bytes32(0), "PTVS: Claim already exists");
        require(ptvsScore <= 100, "PTVS: Invalid score");
        require(forensicHash != bytes32(0), "PTVS: Invalid forensic hash");
        require(inspectionTimestamp <= block.timestamp, "PTVS: Future timestamp");
        require(
            inspectionTimestamp >= block.timestamp - 30 days,
            "PTVS: Inspection too old"
        );

        // Verify PTCE signature over the claim
        bytes32 structHash = keccak256(abi.encode(
            CLAIM_TYPEHASH,
            assetId,
            ptvsScore,
            forensicHash,
            inspectionTimestamp,
            msg.sender
        ));
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = digest.recover(ptceSignature);
        require(signer == msg.sender, "PTVS: Invalid PTCE signature");

        // Determine claim status
        ClaimStatus status;
        if (ptvsScore >= VERIFIED_THRESHOLD) {
            status = ClaimStatus.VERIFIED;
        } else if (ptvsScore >= CONDITIONAL_THRESHOLD) {
            status = ClaimStatus.CONDITIONAL;
        } else {
            status = ClaimStatus.REVOKED;
        }

        // Store the claim
        claims[assetId] = VerifiableClaim({
            assetId: assetId,
            ptvsScore: ptvsScore,
            forensicHash: forensicHash,
            inspectionTimestamp: inspectionTimestamp,
            ptceAddress: msg.sender,
            status: status,
            lastReauditTimestamp: inspectionTimestamp,
            version: 1,
            injectedAt: block.timestamp
        });

        allClaimIds.add(assetId);
        totalClaimsInjected++;
        ptces[msg.sender].totalInspections++;

        emit ClaimInjected(
            assetId,
            ptvsScore,
            forensicHash,
            msg.sender,
            block.timestamp,
            status
        );

        // Trigger circuit breaker if score too low
        if (status == ClaimStatus.REVOKED) {
            emit CircuitBreakerTriggered(
                assetId,
                ptvsScore,
                "Trading paused - Score below threshold",
                block.timestamp
            );
        }
    }

    // ============ CLAIM RENEWAL (RE-AUDIT) ============

    function renewClaim(
        bytes32 assetId,
        uint8 newScore,
        bytes32 newForensicHash,
        uint256 newInspectionTimestamp,
        bytes memory ptceSignature
    ) external onlyActivePTCE claimExists(assetId) {
        require(newScore <= 100, "PTVS: Invalid score");
        require(newForensicHash != bytes32(0), "PTVS: Invalid forensic hash");
        require(
            newInspectionTimestamp > claims[assetId].inspectionTimestamp,
            "PTVS: New inspection must be after previous"
        );

        // Verify PTCE signature
        bytes32 structHash = keccak256(abi.encode(
            CLAIM_TYPEHASH,
            assetId,
            newScore,
            newForensicHash,
            newInspectionTimestamp,
            msg.sender
        ));
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = digest.recover(ptceSignature);
        require(signer == msg.sender, "PTVS: Invalid PTCE signature");

        // Determine new status
        ClaimStatus newStatus;
        if (newScore >= VERIFIED_THRESHOLD) {
            newStatus = ClaimStatus.VERIFIED;
        } else if (newScore >= CONDITIONAL_THRESHOLD) {
            newStatus = ClaimStatus.CONDITIONAL;
        } else {
            newStatus = ClaimStatus.REVOKED;
        }

        uint256 newVersion = claims[assetId].version + 1;
        claims[assetId] = VerifiableClaim({
            assetId: assetId,
            ptvsScore: newScore,
            forensicHash: newForensicHash,
            inspectionTimestamp: newInspectionTimestamp,
            ptceAddress: msg.sender,
            status: newStatus,
            lastReauditTimestamp: newInspectionTimestamp,
            version: newVersion,
            injectedAt: claims[assetId].injectedAt
        });

        totalReaudits++;
        ptces[msg.sender].totalInspections++;

        emit ClaimRenewed(
            assetId,
            newScore,
            newForensicHash,
            block.timestamp,
            newStatus,
            newVersion
        );
    }

    // ============ CLAIM REVOCATION (GOVERNANCE CONTROLLED) ============

    /**
     * @notice Revoke a claim (requires governance + timelock)
     * @dev Cannot be called unilaterally by PTCE or owner
     */
    function revokeClaim(
        bytes32 assetId,
        string calldata reason
    ) external onlyTimelock claimExists(assetId) {
        claims[assetId].status = ClaimStatus.REVOKED;
        totalRevocations++;

        emit ClaimRevoked(assetId, reason, block.timestamp, msg.sender);
        emit CircuitBreakerTriggered(
            assetId,
            claims[assetId].ptvsScore,
            reason,
            block.timestamp
        );
    }

    // ============ DISPUTE INTEGRATION ============

    /**
     * @notice Mark a claim as disputed (called by governance)
     */
    function markClaimDisputed(
        bytes32 assetId,
        uint256 disputeId
    ) external onlyGovernanceOrTimelock claimExists(assetId) {
        claims[assetId].status = ClaimStatus.DISPUTED;
        totalDisputesTriggered++;
        
        emit ClaimDisputed(assetId, disputeId, msg.sender, block.timestamp);
    }

    /**
     * @notice Restore claim after dispute resolution (called by governance)
     */
    function restoreClaimAfterDispute(
        bytes32 assetId,
        ClaimStatus newStatus
    ) external onlyGovernanceOrTimelock claimExists(assetId) {
        claims[assetId].status = newStatus;
    }

    // ============ CLAIM EXPIRATION ============

    function checkExpiration(bytes32 assetId) external claimExists(assetId) {
        VerifiableClaim storage claim = claims[assetId];
        
        if (
            claim.status != ClaimStatus.REVOKED &&
            claim.status != ClaimStatus.DISPUTED &&
            block.timestamp > claim.lastReauditTimestamp + REAUDIT_INTERVAL
        ) {
            claim.status = ClaimStatus.EXPIRED;
            emit ClaimExpired(assetId, block.timestamp);
        }
    }

    function batchCheckExpiration(bytes32[] calldata assetIds) external {
        for (uint256 i = 0; i < assetIds.length; i++) {
            if (claims[assetIds[i]].assetId != bytes32(0)) {
                VerifiableClaim storage claim = claims[assetIds[i]];
                if (
                    claim.status != ClaimStatus.REVOKED &&
                    claim.status != ClaimStatus.DISPUTED &&
                    block.timestamp > claim.lastReauditTimestamp + REAUDIT_INTERVAL
                ) {
                    claim.status = ClaimStatus.EXPIRED;
                    emit ClaimExpired(assetIds[i], block.timestamp);
                }
            }
        }
    }

    // ============ VIEW FUNCTIONS ============

    function getClaim(bytes32 assetId) external view returns (VerifiableClaim memory) {
        return claims[assetId];
    }

    function isClaimValid(bytes32 assetId) external view returns (bool) {
        return claims[assetId].status == ClaimStatus.VERIFIED;
    }

    function isClaimTradable(bytes32 assetId) external view returns (bool) {
        ClaimStatus status = claims[assetId].status;
        return status == ClaimStatus.VERIFIED || status == ClaimStatus.CONDITIONAL;
    }

    function getClaimStatus(bytes32 assetId) external view returns (ClaimStatus) {
        return claims[assetId].status;
    }

    function getAllClaims() external view returns (bytes32[] memory) {
        return allClaimIds.values();
    }

    function getClaimCount() external view returns (uint256) {
        return totalClaimsInjected;
    }

    function getPTCEInfo(address ptceAddress) external view returns (PTCEInfo memory) {
        return ptces[ptceAddress];
    }

    function getActivePTCEs() external view returns (address[] memory) {
        return activePTCEs.values();
    }

    function getActivePTCECount() external view returns (uint256) {
        return activePTCEs.length();
    }

    function getStandardInfo() external pure returns (string memory, string memory, string memory) {
        return (STANDARD_VERSION, STANDARD_DOI, CONTRACT_VERSION);
    }

    function getGovernanceInfo() external view returns (address, address) {
        return (governance, timelock);
    }

    // NOTE: NO emergencyRevokeAll() function
    // All revocations require governance vote + timelock execution
    // This is intentional - single-entity emergency powers are a centralization risk
}
