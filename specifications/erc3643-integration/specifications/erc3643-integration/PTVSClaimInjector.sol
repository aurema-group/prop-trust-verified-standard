// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ═══════════════════════════════════════════════════════════════
//  OpenZeppelin Dependencies (v4.9.x)
//  Para migrar a v5.x: constructor() EIP712(...) Ownable(msg.sender) {}
// ═══════════════════════════════════════════════════════════════
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// ═══════════════════════════════════════════════════════════════
//  ERC-3643 / T-REX INTERFACES
//  Definidas explícitamente para compatibilidad ABI con herramientas
//  externas (ethers.js, web3.js, compiladores, ERC-3643 tooling).
// ═══════════════════════════════════════════════════════════════

/// @notice Minimal ONCHAINID identity interface (T-REX)
interface IIdentity {
    function keyHasPurpose(bytes32 key, uint256 purpose)
        external view returns (bool);
}

/// @notice Claim Issuer interface (T-REX / ERC-3643)
/// @dev Los Compliance Modules de ERC-3643 consultan esta interfaz
///      vía staticcall antes de permitir cada transferencia.
interface IClaimIssuer {
    function isClaimValid(
        IIdentity _identity,
        uint256 _claimTopic,
        bytes calldata _sig,
        bytes calldata _data
    ) external view returns (bool);

    function revokeClaim(
        IIdentity _identity,
        uint256 _claimTopic,
        bytes calldata _sig,
        bytes calldata _data
    ) external returns (bool);
}

/**
 * ═══════════════════════════════════════════════════════════════
 *  PTVSClaimInjector v1.0.2 — ERC-3643 Compatible (Staticcall-safe)
 * ═══════════════════════════════════════════════════════════════
 *
 * @title  PTVSClaimInjector v1.0.2 (ERC-3643 Safe + Strict Binding)
 * @author Aurelio Tamarit Blay · Forensics Oracle Initiative
 * @notice Verifiable Claim injection for PTVS v1.0 with
 *         ERC-3643/T-REX IClaimIssuer integration.
 *
 * FIX LOG:
 *   v1.0.0 → v1.0.1:
 *     - isClaimValid() ahora es view puro (compatible con staticcall)
 *     - Eliminadas mutaciones de estado en isClaimValid()
 *     - Contador totalERC3643Queries eliminado (no view-safe)
 *     - Eventos movidos fuera del path de staticcall
 *     - Implementadas funciones auxiliares faltantes
 *
 *   v1.0.1 → v1.0.2:
 *     - Herencia explícita de IClaimIssuer (compatibilidad ABI)
 *     - Binding obligatorio: isClaimValid denega si identity no vinculada
 *     - Eliminado path de fallback para consultas sin binding
 *
 * GOVERNANCE: Model A+ (Expert Authorship + Advisory Board)
 * STANDARD:   DOI 10.5281/zenodo.21719175 (CERN/Zenodo)
 */
contract PTVSClaimInjector is IClaimIssuer, EIP712, Ownable, Pausable {
    using ECDSA for bytes32;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    // ═══════════════════════════════════════════════════════════
    //  CONSTANTS
    // ═══════════════════════════════════════════════════════════

    string public constant STANDARD_VERSION = "PTVS v1.0";
    string public constant STANDARD_DOI = "10.5281/zenodo.21719175";
    string public constant CONTRACT_VERSION = "1.0.2-erc3643-strict";
    string public constant GOVERNANCE_MODEL =
        "Model A+ (Expert Authorship + Advisory Board)";
    string public constant ERC3643_COMPATIBILITY =
        "T-REX / IClaimIssuer (staticcall-safe, strict binding)";

    uint256 public constant DEFAULT_PTVS_CLAIM_TOPIC = 10101;
    uint256 public constant MAX_INSPECTION_AGE = 30 days;
    uint256 public constant REAUDIT_INTERVAL = 90 days;
    uint8 public constant VERIFIED_THRESHOLD = 70;
    uint8 public constant CONDITIONAL_THRESHOLD = 50;

    bytes32 private constant CLAIM_TYPEHASH = keccak256(
        "VerifiableClaim(bytes32 assetId,uint8 ptvsScore,"
        "bytes32 forensicHash,uint256 inspectionTimestamp,"
        "address ptceAddress)"
    );

    // ═══════════════════════════════════════════════════════════
    //  ENUMS
    // ═══════════════════════════════════════════════════════════

    enum ClaimStatus {
        VERIFIED,    // 70-100 → trading enabled
        CONDITIONAL, // 50-69  → trading with haircut
        EXPIRED,     // 90+ days sin re-audit
        REVOKED,     // <50 o violación material
        DISPUTED     // bajo revisión del founder
    }

    // ═══════════════════════════════════════════════════════════
    //  STRUCTS
    // ═══════════════════════════════════════════════════════════

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
        uint256 totalInspections;
    }

    // ═══════════════════════════════════════════════════════════
    //  STATE VARIABLES
    // ═══════════════════════════════════════════════════════════

    mapping(bytes32 => VerifiableClaim) public claims;
    mapping(address => PTCEInfo) public ptces;

    /// @notice Bidirectional binding: physical asset ↔ ONCHAINID identity
    /// @dev OBLIGATORIO antes de que ERC-3643 pueda validar transfers
    mapping(bytes32 => address) public assetIdToIdentity;
    mapping(address => bytes32) public identityToAssetId;

    EnumerableSet.Bytes32Set private _allClaimIds;
    EnumerableSet.AddressSet private _activePTCEs;
    EnumerableSet.AddressSet private _registeredComplianceModules;

    uint256 public totalClaimsInjected;
    uint256 public totalReaudits;
    uint256 public totalRevocations;
    uint256 public totalDisputes;

    uint256 public ptvsClaimTopic;

    // ═══════════════════════════════════════════════════════════
    //  EVENTS
    // ═══════════════════════════════════════════════════════════

    event ClaimInjected(
        bytes32 indexed assetId, uint8 ptvsScore,
        bytes32 indexed forensicHash, address indexed ptceAddress,
        uint256 timestamp, ClaimStatus status
    );
    event ClaimRenewed(
        bytes32 indexed assetId, uint8 newScore,
        bytes32 indexed newForensicHash, uint256 timestamp,
        ClaimStatus newStatus, uint256 newVersion
    );
    event ClaimRevoked(
        bytes32 indexed assetId, string reason,
        uint256 timestamp, address indexed revokedBy
    );
    event ClaimExpired(bytes32 indexed assetId, uint256 expiredAt);
    event ClaimDisputed(bytes32 indexed assetId, string reason, uint256 timestamp);
    event DisputeResolved(
        bytes32 indexed assetId, ClaimStatus resolvedStatus, uint256 timestamp
    );
    event CircuitBreakerTriggered(
        bytes32 indexed assetId, uint8 score, string action, uint256 timestamp
    );
    event PTCEAuthorized(
        address indexed ptceAddress, string ptceId,
        string jurisdiction, uint256 timestamp
    );
    event PTCERevoked(address indexed ptceAddress, string reason, uint256 timestamp);

    event ComplianceModuleRegistered(address indexed module, uint256 timestamp);
    event ComplianceModuleRevoked(address indexed module, uint256 timestamp);
    event AssetIdentityBound(
        bytes32 indexed assetId, address indexed identity, uint256 timestamp
    );
    event PTVSClaimTopicUpdated(
        uint256 oldTopic, uint256 newTopic, uint256 timestamp
    );

    // ═══════════════════════════════════════════════════════════
    //  MODIFIERS
    // ═══════════════════════════════════════════════════════════

    modifier onlyActivePTCE() {
        require(ptces[msg.sender].isActive, "PTVS: Not an active PTCE");
        _;
    }

    modifier claimExists(bytes32 assetId) {
        require(claims[assetId].assetId != bytes32(0), "PTVS: Claim does not exist");
        _;
    }

    modifier claimNotDisputed(bytes32 assetId) {
        require(
            claims[assetId].status != ClaimStatus.DISPUTED,
            "PTVS: Claim is disputed"
        );
        _;
    }

    modifier onlyRegisteredCompliance() {
        require(
            _registeredComplianceModules.contains(msg.sender),
            "PTVS: Not a registered Compliance Module"
        );
        _;
    }

    // ═══════════════════════════════════════════════════════════
    //  CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════

    constructor() EIP712("PTVSClaimInjector", "1.0.2") {
        ptvsClaimTopic = DEFAULT_PTVS_CLAIM_TOPIC;
    }

    // ═══════════════════════════════════════════════════════════
    //  ⭐ ERC-3643: IClaimIssuer (STATICCALL-SAFE, STRICT BINDING)
    // ═══════════════════════════════════════════════════════════

    /**
     * @notice IClaimIssuer.isClaimValid — SAFE for ERC-3643 staticcall
     *
     * @dev CRITICAL: esta función es `view` y NO modifica estado.
     *      El Compliance Module de ERC-3643 la invoca vía staticcall
     *      antes de cada transfer.
     *
     *      SECURITY: El binding identity↔asset es OBLIGATORIO.
     *      Si identityToAssetId[_identity] == bytes32(0), la función
     *      retorna false inmediatamente. Esto previene bypass donde
     *      un atacante consulta por assetId sin binding previo.
     *
     *      Flujo correcto de despliegue:
     *      1. injectClaim() → PTCE inyecta el claim
     *      2. bindAssetIdentity() → Owner vincula asset ↔ identity
     *      3. registerComplianceModule() → Owner registra el CM
     *      4. Transfers ERC-3643 → isClaimValid() valida automáticamente
     */
    function isClaimValid(
        IIdentity _identity,
        uint256 _claimTopic,
        bytes calldata /* _sig */,
        bytes calldata _data
    ) external view override returns (bool) {
        // 1. Validar claim topic
        if (_claimTopic != ptvsClaimTopic) {
            return false;
        }

        // 2. SECURITY: Verificar binding OBLIGATORIO
        //    Si la identity no está vinculada a ningún asset,
        //    denegar la validación inmediatamente.
        bytes32 boundAssetId = identityToAssetId[address(_identity)];
        if (boundAssetId == bytes32(0)) {
            return false; // Identity no vinculada → inválido
        }

        // 3. Decodificar assetId de _data
        bytes32 assetId = _decodeAssetId(_data);
        if (assetId == bytes32(0)) {
            return false;
        }

        // 4. Verificar que el assetId decodificado coincide
        //    con el asset vinculado a esta identity
        if (boundAssetId != assetId) {
            return false; // Mismatch: identity vinculada a otro asset
        }

        // 5. Calcular status actual SIN modificar state (view-safe)
        ClaimStatus currentStatus = _computeCurrentStatus(assetId);

        // 6. Retornar validez
        return (currentStatus == ClaimStatus.VERIFIED ||
                currentStatus == ClaimStatus.CONDITIONAL);
    }

    /**
     * @notice IClaimIssuer.revokeClaim — callback de Compliance Module
     * @dev Esta función SÍ modifica state (no es view). Se llama vía
     *      transacción normal, normalmente desde el Compliance Module
     *      al detectar una violación on-chain.
     */
    function revokeClaim(
        IIdentity _identity,
        uint256 _claimTopic,
        bytes calldata /* _sig */,
        bytes calldata _data
    ) external override onlyRegisteredCompliance returns (bool) {
        if (_claimTopic != ptvsClaimTopic) return false;

        bytes32 assetId = _decodeAssetId(_data);
        if (assetId == bytes32(0)) return false;
        if (claims[assetId].assetId == bytes32(0)) return false;
        if (claims[assetId].status == ClaimStatus.REVOKED) return true;

        claims[assetId].status = ClaimStatus.REVOKED;
        totalRevocations++;

        emit ClaimRevoked(
            assetId,
            "Revoked by ERC-3643 Compliance Module",
            block.timestamp,
            msg.sender
        );
        emit CircuitBreakerTriggered(
            assetId,
            claims[assetId].ptvsScore,
            "ERC-3643 Compliance Module triggered revocation",
            block.timestamp
        );

        return true;
    }

    // ═══════════════════════════════════════════════════════════
    //  ERC-3643: MANAGEMENT (state-changing)
    // ═══════════════════════════════════════════════════════════

    /**
     * @notice Bind assetId ↔ ONCHAINID identity (owner-only)
     * @dev OBLIGATORIO antes de que ERC-3643 pueda validar transfers.
     *      Debe llamarse UNA VEZ al desplegar cada token ERC-3643.
     */
    function bindAssetIdentity(bytes32 assetId, address identity)
        external
        onlyOwner
        claimExists(assetId)
    {
        _bindAssetIdentity(assetId, identity);
    }

    /**
     * @notice Bind desde PTCE (alternativa para el PTCE original)
     */
    function bindAssetIdentityAsPTCE(bytes32 assetId, address identity)
        external
        onlyActivePTCE
        claimExists(assetId)
    {
        require(
            claims[assetId].ptceAddress == msg.sender,
            "PTVS: Only original PTCE can bind"
        );
        _bindAssetIdentity(assetId, identity);
    }

    function registerComplianceModule(address complianceModule) external onlyOwner {
        require(complianceModule != address(0), "PTVS: Invalid address");
        require(
            !_registeredComplianceModules.contains(complianceModule),
            "PTVS: Already registered"
        );
        _registeredComplianceModules.add(complianceModule);
        emit ComplianceModuleRegistered(complianceModule, block.timestamp);
    }

    function revokeComplianceModule(address complianceModule) external onlyOwner {
        require(
            _registeredComplianceModules.contains(complianceModule),
            "PTVS: Not registered"
        );
        _registeredComplianceModules.remove(complianceModule);
        emit ComplianceModuleRevoked(complianceModule, block.timestamp);
    }

    function setPTVSClaimTopic(uint256 newTopic) external onlyOwner {
        require(newTopic != 0, "PTVS: Invalid topic");
        uint256 oldTopic = ptvsClaimTopic;
        ptvsClaimTopic = newTopic;
        emit PTVSClaimTopicUpdated(oldTopic, newTopic, block.timestamp);
    }

    // ═══════════════════════════════════════════════════════════
    //  OWNER — PTCE MANAGEMENT
    // ═══════════════════════════════════════════════════════════

    function authorizePTCE(
        address ptceAddress,
        string calldata ptceId,
        string calldata jurisdiction
    ) external onlyOwner {
        require(ptceAddress != address(0), "PTVS: Invalid address");
        require(!ptces[ptceAddress].isActive, "PTVS: Already active");

        ptces[ptceAddress] = PTCEInfo({
            isActive: true,
            ptceId: ptceId,
            jurisdiction: jurisdiction,
            authorizedAt: block.timestamp,
            totalInspections: 0
        });

        _activePTCEs.add(ptceAddress);
        emit PTCEAuthorized(ptceAddress, ptceId, jurisdiction, block.timestamp);
    }

    function revokePTCE(address ptceAddress, string calldata reason) external onlyOwner {
        require(ptces[ptceAddress].isActive, "PTVS: Not active");
        ptces[ptceAddress].isActive = false;
        _activePTCEs.remove(ptceAddress);
        emit PTCERevoked(ptceAddress, reason, block.timestamp);
    }

    // ═══════════════════════════════════════════════════════════
    //  OWNER — CLAIM MANAGEMENT
    // ═══════════════════════════════════════════════════════════

    function revokeClaimByOwner(bytes32 assetId, string calldata reason)
        external onlyOwner claimExists(assetId)
    {
        claims[assetId].status = ClaimStatus.REVOKED;
        totalRevocations++;
        emit ClaimRevoked(assetId, reason, block.timestamp, msg.sender);
        emit CircuitBreakerTriggered(
            assetId, claims[assetId].ptvsScore, reason, block.timestamp
        );
    }

    function disputeClaim(bytes32 assetId, string calldata reason)
        external onlyOwner claimExists(assetId)
    {
        require(
            claims[assetId].status != ClaimStatus.DISPUTED,
            "PTVS: Already disputed"
        );
        claims[assetId].status = ClaimStatus.DISPUTED;
        totalDisputes++;
        emit ClaimDisputed(assetId, reason, block.timestamp);
        emit CircuitBreakerTriggered(
            assetId, claims[assetId].ptvsScore,
            "Dispute initiated — trading restricted", block.timestamp
        );
    }

    function resolveDispute(bytes32 assetId, ClaimStatus newStatus)
        external onlyOwner claimExists(assetId)
    {
        require(claims[assetId].status == ClaimStatus.DISPUTED, "PTVS: Not disputed");
        require(newStatus != ClaimStatus.DISPUTED, "PTVS: Cannot resolve to DISPUTED");
        claims[assetId].status = newStatus;
        emit DisputeResolved(assetId, newStatus, block.timestamp);
        if (newStatus == ClaimStatus.REVOKED) {
            emit CircuitBreakerTriggered(
                assetId, claims[assetId].ptvsScore,
                "Dispute resolved — claim revoked", block.timestamp
            );
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  OWNER — ADMIN
    // ═══════════════════════════════════════════════════════════

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // ═══════════════════════════════════════════════════════════
    //  PTCE — CLAIM INJECTION
    // ═══════════════════════════════════════════════════════════

    function injectClaim(
        bytes32 assetId,
        uint8 ptvsScore,
        bytes32 forensicHash,
        uint256 inspectionTimestamp,
        bytes calldata ptceSignature
    ) external onlyActivePTCE whenNotPaused {
        require(claims[assetId].assetId == bytes32(0), "PTVS: Claim already exists");
        require(ptvsScore <= 100, "PTVS: Invalid score");
        require(forensicHash != bytes32(0), "PTVS: Invalid forensic hash");
        require(inspectionTimestamp <= block.timestamp, "PTVS: Future timestamp");
        require(
            inspectionTimestamp >= block.timestamp - MAX_INSPECTION_AGE,
            "PTVS: Inspection too old (max 30 days)"
        );

        _verifySignature(
            assetId, ptvsScore, forensicHash,
            inspectionTimestamp, msg.sender, ptceSignature
        );

        ClaimStatus status = _scoreToStatus(ptvsScore);

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

        _allClaimIds.add(assetId);
        totalClaimsInjected++;
        ptces[msg.sender].totalInspections++;

        emit ClaimInjected(
            assetId, ptvsScore, forensicHash,
            msg.sender, block.timestamp, status
        );

        if (status == ClaimStatus.REVOKED) {
            emit CircuitBreakerTriggered(
                assetId, ptvsScore,
                "Trading paused — score below threshold",
                block.timestamp
            );
        }
    }

    function renewClaim(
        bytes32 assetId,
        uint8 newScore,
        bytes32 newForensicHash,
        uint256 newInspectionTimestamp,
        bytes calldata ptceSignature
    )
        external
        onlyActivePTCE
        whenNotPaused
        claimExists(assetId)
        claimNotDisputed(assetId)
    {
        require(newScore <= 100, "PTVS: Invalid score");
        require(newForensicHash != bytes32(0), "PTVS: Invalid forensic hash");
        require(
            newInspectionTimestamp > claims[assetId].inspectionTimestamp,
            "PTVS: Must be after previous inspection"
        );

        _verifySignature(
            assetId, newScore, newForensicHash,
            newInspectionTimestamp, msg.sender, ptceSignature
        );

        ClaimStatus newStatus = _scoreToStatus(newScore);
        uint256 newVersion = claims[assetId].version + 1;

        claims[assetId].ptvsScore = newScore;
        claims[assetId].forensicHash = newForensicHash;
        claims[assetId].inspectionTimestamp = newInspectionTimestamp;
        claims[assetId].ptceAddress = msg.sender;
        claims[assetId].status = newStatus;
        claims[assetId].lastReauditTimestamp = newInspectionTimestamp;
        claims[assetId].version = newVersion;

        totalReaudits++;
        ptces[msg.sender].totalInspections++;

        emit ClaimRenewed(
            assetId, newScore, newForensicHash,
            block.timestamp, newStatus, newVersion
        );

        if (newStatus == ClaimStatus.REVOKED) {
            emit CircuitBreakerTriggered(
                assetId, newScore,
                "Trading paused — re-audit score below threshold",
                block.timestamp
            );
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  PUBLIC — EXPIRATION (state-changing)
    // ═══════════════════════════════════════════════════════════

    function checkExpiration(bytes32 assetId) external claimExists(assetId) {
        _applyExpiry(assetId);
    }

    function batchCheckExpiration(bytes32[] calldata assetIds) external {
        for (uint256 i = 0; i < assetIds.length; i++) {
            if (claims[assetIds[i]].assetId != bytes32(0)) {
                _applyExpiry(assetIds[i]);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════

    function getClaim(bytes32 assetId)
        external view returns (VerifiableClaim memory)
    { return claims[assetId]; }

    function getClaimStatus(bytes32 assetId) external view returns (ClaimStatus) {
        return _computeCurrentStatus(assetId);
    }

    function isClaimValidDirect(bytes32 assetId) external view returns (bool) {
        return _computeCurrentStatus(assetId) == ClaimStatus.VERIFIED;
    }

    function isClaimTradable(bytes32 assetId) external view returns (bool) {
        ClaimStatus s = _computeCurrentStatus(assetId);
        return s == ClaimStatus.VERIFIED || s == ClaimStatus.CONDITIONAL;
    }

    function getAllClaims() external view returns (bytes32[] memory) {
        return _allClaimIds.values();
    }

    function getClaimCount() external view returns (uint256) {
        return totalClaimsInjected;
    }

    function getPTCEInfo(address ptceAddress)
        external view returns (PTCEInfo memory)
    { return ptces[ptceAddress]; }

    function isPTCEActive(address ptceAddress) external view returns (bool) {
        return ptces[ptceAddress].isActive;
    }

    function getActivePTCEs() external view returns (address[] memory) {
        return _activePTCEs.values();
    }

    function getActivePTCECount() external view returns (uint256) {
        return _activePTCEs.length();
    }

    function getAssetIdentity(bytes32 assetId) external view returns (address) {
        return assetIdToIdentity[assetId];
    }

    function getIdentityAsset(address identity) external view returns (bytes32) {
        return identityToAssetId[identity];
    }

    function getRegisteredComplianceModules()
        external view returns (address[] memory)
    { return _registeredComplianceModules.values(); }

    function isComplianceModuleRegistered(address module)
        external view returns (bool)
    { return _registeredComplianceModules.contains(module); }

    function isClaimValidByIdentity(address identity) external view returns (bool) {
        bytes32 assetId = identityToAssetId[identity];
        if (assetId == bytes32(0)) return false;
        ClaimStatus s = _computeCurrentStatus(assetId);
        return s == ClaimStatus.VERIFIED || s == ClaimStatus.CONDITIONAL;
    }

    function getStandardInfo()
        external
        pure
        returns (
            string memory version,
            string memory doi,
            string memory contractVer,
            string memory governance,
            string memory erc3643Compat
        )
    {
        return (
            STANDARD_VERSION, STANDARD_DOI, CONTRACT_VERSION,
            GOVERNANCE_MODEL, ERC3643_COMPATIBILITY
        );
    }

    function getContractStats()
        external
        view
        returns (
            uint256 _claims,
            uint256 _reaudits,
            uint256 _revocations,
            uint256 _disputes,
            uint256 _activePTCEs,
            uint256 _complianceModules,
            uint256 _claimTopic
        )
    {
        return (
            totalClaimsInjected, totalReaudits, totalRevocations, totalDisputes,
            _activePTCEs.length(), _registeredComplianceModules.length(),
            ptvsClaimTopic
        );
    }

    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    // ═══════════════════════════════════════════════════════════
    //  INTERNAL HELPERS
    // ═══════════════════════════════════════════════════════════

    /**
     * @dev Calcula status actual considerando expiración,
     *      SIN modificar state (view-safe).
     */
    function _computeCurrentStatus(bytes32 assetId)
        internal
        view
        returns (ClaimStatus)
    {
        VerifiableClaim storage c = claims[assetId];

        if (c.assetId == bytes32(0)) {
            return ClaimStatus.REVOKED; // inexistente = inválido
        }

        if (c.status == ClaimStatus.REVOKED ||
            c.status == ClaimStatus.DISPUTED) {
            return c.status;
        }

        if (block.timestamp > c.lastReauditTimestamp + REAUDIT_INTERVAL) {
            return ClaimStatus.EXPIRED;
        }

        return c.status;
    }

    /**
     * @dev Aplica expiración modificando state (solo llamadas no-view)
     */
    function _applyExpiry(bytes32 assetId) internal {
        VerifiableClaim storage c = claims[assetId];
        if (
            c.status != ClaimStatus.REVOKED &&
            c.status != ClaimStatus.DISPUTED &&
            c.assetId != bytes32(0) &&
            block.timestamp > c.lastReauditTimestamp + REAUDIT_INTERVAL
        ) {
            c.status = ClaimStatus.EXPIRED;
            emit ClaimExpired(assetId, block.timestamp);
            emit CircuitBreakerTriggered(
                assetId, c.ptvsScore,
                "Claim expired — re-audit required",
                block.timestamp
            );
        }
    }

    function _scoreToStatus(uint8 score) internal pure returns (ClaimStatus) {
        if (score >= VERIFIED_THRESHOLD) return ClaimStatus.VERIFIED;
        if (score >= CONDITIONAL_THRESHOLD) return ClaimStatus.CONDITIONAL;
        return ClaimStatus.REVOKED;
    }

    /**
     * @dev Decode assetId desde el campo _data de IClaimIssuer.
     *      Convención: los primeros 32 bytes son el assetId.
     */
    function _decodeAssetId(bytes calldata data)
        internal
        pure
        returns (bytes32 assetId)
    {
        if (data.length < 32) {
            return bytes32(0);
        }
        assembly {
            assetId := calldataload(data.offset)
        }
    }

    /**
     * @dev Vincula bidireccionalmente assetId ↔ ONCHAINID identity
     */
    function _bindAssetIdentity(bytes32 assetId, address identity) internal {
        require(identity != address(0), "PTVS: Invalid identity");
        require(assetId != bytes32(0), "PTVS: Invalid assetId");

        assetIdToIdentity[assetId] = identity;
        identityToAssetId[identity] = assetId;

        emit AssetIdentityBound(assetId, identity, block.timestamp);
    }

    /**
     * @dev Verifica firma EIP-712 del PTCE sobre el claim
     */
    function _verifySignature(
        bytes32 assetId,
        uint8 ptvsScore,
        bytes32 forensicHash,
        uint256 inspectionTimestamp,
        address ptceAddress,
        bytes calldata signature
    ) internal view {
        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_TYPEHASH,
                assetId,
                ptvsScore,
                forensicHash,
                inspectionTimestamp,
                ptceAddress
            )
        );
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = digest.recover(signature);
        require(signer == ptceAddress, "PTVS: Invalid PTCE signature");
    }
}
