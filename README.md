# Prop Trust Verified Standard (PTVS v1.0)
### A Deterministic Off-Chain Oracle Framework for Real World Asset (RWA) Tokenization

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21719175.svg)](https://doi.org/10.5281/zenodo.21719175)
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC_BY_4.0-blue.svg)](https://creativecommons.org/licenses/by/4.0/)
[![Ecosystem](https://img.shields.io/badge/RWA-ERC--3643%20Compatible-green.svg)](https://www.erc3643.org/)
[![Status](https://img.shields.io/badge/Status-Active%20v1.0-brightgreen.svg)]()

> **The Mandatory Off-Chain Companion for ERC-3643 & Permissioned RWA Tokenization Protocols.**

---

## 📌 Executive Summary

While protocols such as **ERC-3643** effectively govern on-chain permissioned compliance, identity management (ONCHAINID), and transfer eligibility, they fundamentally rely on the assumption that the underlying physical asset is legally clear, structurally sound, and accurately valued. 

The **Prop Trust Verified Standard (PTVS v1.0)** bridges this critical gap by resolving the **Physical Oracle Problem**. PTVS introduces a deterministic, standardized methodology for off-chain physical, legal, and structural auditing before token minting occurs.

By integrating certified judicial engineering, cryptographic timestamps, and standardized risk metrics, PTVS eliminates "toxic RWAs" and provides institutional investors with verifiable off-chain certainty.

---

## 🏛️ System Architecture & Framework

PTVS v1.0 operates as a multi-layered off-chain verification pipeline feeding deterministic compliance payloads directly to smart contract registries:
---

## 📑 Technical Paper & Academic References

The complete mathematical, legal, and cryptographic specifications of PTVS v1.0 are published under open-access research licenses:

* **Title:** Prop Trust Verified Standard (PTVS v1.0): A Deterministic Off-Chain Oracle Framework for Real World Asset (RWA) Tokenization
* **Author:** Aurelio Tamarit Blay (*Principal Researcher, Aurema Group L.L.C.*)
* **ORCID:** [0009-0007-5824-3602](https://orcid.org/0009-0007-5824-3602)
* **Zenodo DOI:** [10.5281/zenodo.21719175](https://doi.org/10.5281/zenodo.21719175)
* **arXiv Preprint:** `arXiv Pending (Ticket AH-201262 / submit/7897765)`

---

## 🔗 Integration with ERC-3643

PTVS v1.0 fits directly into the ERC-3643 architecture as a specialized **Trusted Claim Issuer**:

1. **Audit Execution:** Certified judicial experts complete physical and title verification.
2. **Claim Issuance:** The PTVS Oracle issues an ONCHAINID Claim containing:
   - `Claim Topic:` `PTVS_PHYSICAL_VERIFICATION_TOPIC`
   - `Issuer:` Aurema Group / Prop Trust Verified Node
   - `Payload Signature:` `keccak256(PTVS_Report_Hash + ExpirationTimestamp + AuditScore)`
3. **Compliance Verification:** The ERC-3643 `Compliance` contract checks for a valid, non-expired PTVS Claim before allowing token creation or peer-to-peer transfers.

---

## 📜 Intellectual Property & Citation

Published by **Aurema Group L.L.C.** (Delaware, USA).

```bibtex
@techreport{tamarit2026ptvs,
  author       = {Tamarit Blay, Aurelio},
  title        = {{Prop Trust Verified Standard (PTVS v1.0): A Deterministic Off-Chain Oracle Framework for Real World Asset (RWA) Tokenization}},
  institution  = {Aurema Group L.L.C.},
  year         = {2026},
  month        = {July},
  doi          = {10.5281/zenodo.21719175},
  url          = {[https://doi.org/10.5281/zenodo.21719175](https://doi.org/10.5281/zenodo.21719175)}
PTVS v1.0 operates as a multi-layered off-chain verification pipeline feeding deterministic compliance payloads directly to smart contract registries:

## 🏛️ System Architecture & Framework

PTVS v1.0 operates as a multi-layered off-chain verification pipeline feeding deterministic compliance payloads directly to smart contract registries:

```text
+-----------------------------------------------------------------------+
|                    PHYSICAL & JUDICIAL AUDIT LAYER                    |
|  - Judicial Peritorial Inspection (Certification No. 0161)           |
|  - Structural Pathology & Load-Bearing Verification                   |
|  - Legal Encumbrances & Registry Title Cleanliness Audit              |
+-----------------------------------------------------------------------+
                                   │
                                   ▼
+-----------------------------------------------------------------------+
|                    DETERMINISTIC PTVS SCORING SYSTEM                  |
|  - Risk Metric Calculation (PTVS-Score: 0 - 100)                      |
|  - Cryptographic Hash Generation (SHA-256 Digest of Full Report)     |
|  - Immutable Timestamping (RFC 3161 / Public Ledger Anchor)          |
+-----------------------------------------------------------------------+
                                   │
                                   ▼
+-----------------------------------------------------------------------+
|                       ON-CHAIN INTERFACE LAYER                        |
|  - ERC-3643 Identity Claim Topic Integration (ONCHAINID Claim)         |
|  - Oracle Attestation Feed to Compliance Module                       |
|  - Automated Minting Eligibility Gate                                 |
+-----------------------------------------------------------------------+
```
