// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PTVSAPRISInjector
 * @author PropTrust Association & Aurema Group L.L.C.
 * @notice Extensión del estándar PTVS v1.0 para la gestión dinámica del ciclo de vida RWA,
 *         circuit breakers y triggers paramétricos actuariales (APRIS).
 * @dev Vincula la firma criptográfica off-chain del PTCE (eIDAS 2.0 QES) con la ejecución 
 *      on-chain en protocolos permissioned (ERC-3643 / ONCHAINID).
 */
contract PTVSAPRISInjector is ReentrancyGuard, Ownable {
    using ECDSA for bytes32;

    // --- INTERFACES EXTERNAS ---
    interface ITokenTransferPolicy {
        function setTokenPaused(bool paused) external;
    }

    interface IEscrowManager {
        function releaseCapex(bytes32 assetId, uint256 amount, address beneficiary) external;
    }

    // --- ESTRUCTURAS ---
    struct ParametricTrigger {
        bytes32 assetId;            // Identificador unívoco del RWA físico
        uint8 prrbRating;           // Rating físico actuarial (1 = AAA, 5 = BBB, etc.)
        uint256 capexReleaseAmount; // Monto autorizado para liberación en Escrow (en wei)
        bool circuitBreakerActive;  // Bandera de parada de emergencia (Freeze Trading)
        uint256 timestamp;          // Momento de la inyección forense
        bytes32 forensicReportHash; // Hash SHA-256 del informe pericial off-chain (IPFS/Arweave)
        uint256 nonce;              // Número único para prevenir replay attacks
        bytes signature;            // Firma ECDSA del PTCE autorizado
    }

    // --- VARIABLES DE ESTADO ---
    mapping(address => bool) public authorizedPTCEs;
    mapping(bytes32 => uint8) public assetCurrentRating;
    mapping(bytes32 => bool) public assetCircuitBreaker;
    mapping(address => uint256) public ptceNonces; // Prevención de replay por firmante

    // --- EVENTOS ---
    event CapexEscrowReleased(bytes32 indexed assetId, uint256 amount, bytes32 forensicReportHash, uint256 timestamp);
    event YieldRatingAdjusted(bytes32 indexed assetId, uint8 oldRating, uint8 newRating, bytes32 forensicReportHash, uint256 timestamp);
    event TradingCircuitBreakerTriggered(bytes32 indexed assetId, bool status, bytes32 forensicReportHash, uint256 timestamp);
    event PTCEStatusUpdated(address indexed ptce, bool status, uint256 timestamp);

    // --- MODIFICADORES ---
    modifier onlyAuthorizedPTCE(address signer) {
        require(authorizedPTCEs[signer], "APRIS: Signer is not an authorized PTCE");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor(address[] memory initialPTCEs) Ownable(msg.sender) {
        for (uint256 i = 0; i < initialPTCEs.length; i++) {
            require(initialPTCEs[i] != address(0), "APRIS: Invalid PTCE address");
            authorizedPTCEs[initialPTCEs[i]] = true;
        }
    }

    /**
     * @notice Inyecta un trigger paramétrico verificado criptográficamente por un PTCE.
     * @param trigger Estructura con los datos del estado físico y financiero del RWA.
     * @param escrowContract Dirección del contrato de gestión de fondos (Escrow).
     * @param tokenPolicyContract Dirección del contrato de política de transferencia del token (ERC-3643).
     * @param beneficiary Dirección que recibe los fondos de CAPEX (ej. contratista verificado).
     */
    function executeParametricTrigger(
        ParametricTrigger calldata trigger,
        address escrowContract,
        address tokenPolicyContract,
        address beneficiary
    ) external nonReentrant {
        // 1. Validación de Timestamp (no permitir fechas futuras)
        require(trigger.timestamp <= block.timestamp, "APRIS: Invalid future timestamp");

        // 2. Reconstrucción del hash firmado y recuperación del firmante
        bytes32 messageHash = keccak256(abi.encodePacked(
            trigger.assetId,
            trigger.prrbRating,
            trigger.capexReleaseAmount,
            trigger.circuitBreakerActive,
            trigger.timestamp,
            trigger.forensicReportHash,
            trigger.nonce
        ));
        
        address signer = messageHash.recover(trigger.signature);
        require(authorizedPTCEs[signer], "APRIS: Invalid or unauthorized PTCE signature");

        // 3. Prevención de Replay Attack
        require(trigger.nonce == ptceNonces[signer], "APRIS: Invalid nonce (replay attempt)");
        ptceNonces[signer]++; // Incrementar nonce para el próximo uso

        // 4. Procesamiento de Liberación de CAPEX (Caso de Uso 1)
        if (trigger.capexReleaseAmount > 0 && escrowContract != address(0)) {
            IEscrowManager(escrowContract).releaseCapex(trigger.assetId, trigger.capexReleaseAmount, beneficiary);
            emit CapexEscrowReleased(trigger.assetId, trigger.capexReleaseAmount, trigger.forensicReportHash, block.timestamp);
        }

        // 5. Procesamiento de Ajuste de Rating / Yield (Caso de Uso 2)
        uint8 previousRating = assetCurrentRating[trigger.assetId];
        if (previousRating != trigger.prrbRating && trigger.prrbRating > 0) {
            assetCurrentRating[trigger.assetId] = trigger.prrbRating;
            emit YieldRatingAdjusted(trigger.assetId, previousRating, trigger.prrbRating, trigger.forensicReportHash, block.timestamp);
        }

        // 6. Procesamiento de Circuit Breaker (Caso de Uso 3)
        if (assetCircuitBreaker[trigger.assetId] != trigger.circuitBreakerActive && tokenPolicyContract != address(0)) {
            assetCircuitBreaker[trigger.assetId] = trigger.circuitBreakerActive;
            ITokenTransferPolicy(tokenPolicyContract).setTokenPaused(trigger.circuitBreakerActive);
            emit TradingCircuitBreakerTriggered(trigger.assetId, trigger.circuitBreakerActive, trigger.forensicReportHash, block.timestamp);
        }
    }

    /**
     * @notice Permite al propietario (Gobernanza) añadir o revocar PTCEs.
     */
    function updatePTCEStatus(address ptceAddress, bool status) external onlyOwner {
        require(ptceAddress != address(0), "APRIS: Invalid address");
        authorizedPTCEs[ptceAddress] = status;
        emit PTCEStatusUpdated(ptceAddress, status, block.timestamp);
    }
}
