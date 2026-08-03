# Prop Trust Verified Standard (PTVS v1.0)
## Formal Technical Specification (ISO/IEC Style format)

- **Standard Identifier:** PTVS-SPEC-2026-V1
- **Canonical DOI:** [10.5281/zenodo.21719175](https://doi.org/10.5281/zenodo.21719175)
- **Author / Lead Investigator:** Aurelio Tamarit Blay (ORCID: [0009-0007-5824-3602](https://orcid.org/0009-0007-5824-3602))
- **Status:** Canonical Release (v1.0.0)
- **License:** Creative Commons Attribution 4.0 International (CC BY 4.0)

---

## 1. Scope & Objective
This specification defines the deterministic off-chain physical oracle framework for Real-World Asset (RWA) tokenization. The Prop Trust Verified Standard (PTVS) resolves the "Physical Oracle Problem" by coupling judicial-grade forensic auditing with distributed ledger technology and smart contract identity frameworks (ERC-3643 / ONCHAINID).

## 2. Normative References
- **ISO/IEC 27001:** Information Security Management.
- **ERC-3643:** Permissioned Tokens Standard (Identity & Compliance).
- **ERC-735 / ERC-734:** Claim Issuer & Identity Management Standards.
- **EIP-712:** Typed Structured Data Hashing and Signing.

## 3. Core Architecture & Verification Lifecycle
1. **Off-Chain Physical Forensic Audit:** Performed by a Prop Trust Certified Expert (PTCE).
2. **Hash Generation & DOI Binding:** Compilation of the forensic PDF report, computing the SHA-256 digest, and archiving on IPFS/Zenodo.
3. **Deterministic Claim Creation:** Structuring the JSON payload according to the canonical PTVS Schema.
4. **On-Chain Identity Injection:** Execution of `addClaim` on the asset's ONCHAINID Identity contract via `PTVSClaimInjector.sol`.

## 4. Schema & Data Integrity Specifications
Refer to `/specifications/erc3643-integration/ptvs-claim-schema.json` for the normative JSON Schema definition.
