# Prop Trust Verified Standard (PTVS v1.0)

> **A Deterministic Off-Chain Oracle Framework for Real World Asset (RWA) Tokenization**  
> *The Mandatory Off-Chain Companion for ERC-3643 & Permissioned RWA Tokenization Protocols.*

---

## 📌 Executive Summary

While protocols such as **ERC-3643** effectively govern on-chain permissioned compliance, identity management (**ONCHAINID**), and transfer eligibility, they fundamentally rely on the assumption that the underlying physical asset is legally clear, structurally sound, and accurately valued.

The **Prop Trust Verified Standard (PTVS v1.0)** bridges this critical gap by resolving the *Physical Oracle Problem*. PTVS introduces a deterministic, standardized methodology for off-chain physical, legal, and structural auditing before token minting occurs.

By integrating certified judicial engineering, cryptographic timestamps, and standardized risk metrics, PTVS eliminates "toxic RWAs" and provides institutional investors with verifiable off-chain certainty.

---

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


---

## 📑 Technical Paper & Academic References

The complete mathematical, legal, and cryptographic specifications of PTVS v1.0 are published under open-access research licenses:

* **Title:** Prop Trust Verified Standard (PTVS v1.0): A Deterministic Off-Chain Oracle Framework for Real World Asset (RWA) Tokenization
* **Author:** Aurelio Tamarit Blay *(Principal Researcher, Aurema Group L.L.C.)*
* **ORCID:** [0009-0007-5824-3602](https://orcid.org/0009-0007-5824-3602)
* **Zenodo DOI:** [10.5281/zenodo.21719175](https://doi.org/10.5281/zenodo.21719175)
* **arXiv Preprint:** Pending Announcement *(Submission ID: 7897765, Category: cs.CR)*

---

## 🔗 Integration with ERC-3643

PTVS v1.0 fits directly into the ERC-3643 architecture as a specialized **Trusted Claim Issuer**:

1. **Audit Execution:** Certified judicial experts complete physical and title verification.
2. **Claim Issuance:** The PTVS Oracle issues an ONCHAINID Claim containing:
   * **Claim Topic:** `PTVS_PHYSICAL_VERIFICATION_TOPIC`
   * **Issuer:** Aurema Group / Prop Trust Verified Node
   * **Payload Signature:** $\text{keccak256}(\text{PTVS\_Report\_Hash} + \text{ExpirationTimestamp} + \text{AuditScore})$
3. **Compliance Verification:** The ERC-3643 Compliance contract checks for a valid, non-expired PTVS Claim before allowing token creation or peer-to-peer transfers.

---

## 📚 Official Documentation & Technical Specifications

The PTVS ecosystem is fully documented across institutional, technical, and academic layers:

### 📘 Institutional & Standard Specifications
* [ISO-Style Technical Specification (PDF)](./specifications/PTVS-Technical-Specification-v1.0.pdf) — Formal standard document following ISO/IEC formatting guidelines.
* [ISO-Style Technical Specification (Markdown)](./specifications/PTVS-Technical-Specification-v1.0.md) — Web-indexable specification for search engines and AI agents.
* [International Executive Dossier (PDF)](./docs/PTVS-Executive-Dossier.pdf) — High-level institutional overview for investors, regulators, and partners.
* [International Executive Dossier (Markdown)](./docs/PTVS-Executive-Dossier.md) — Markdown version of the institutional dossier.

### 🔧 Technical Specifications & ERC-3643 Integration
* [ERC-3643 Integration Guide & Reference Code](./docs/ERC3643-Integration-Guide.md) — Architecture guide for injecting PTVS claims into ONCHAINID contracts.
* [Canonical PTVS Claim JSON Schema](./schemas/ptvs-claim.schema.json) — The standard JSON Schema payload defining off-chain physical audit evidence.
* [Solidity Contract: `PTVSClaimInjector.sol`](./contracts/PTVSClaimInjector.sol) — Reference smart contract implementation for on-chain identity claims.
* [Real-World Example: Navarrés Project Claim](./examples/SPV-NAV-2026-001.json) — Real-world JSON implementation for SPV asset verification (`SPV-NAV-2026-001`).

### 🎓 Academic Research & Persistent Identifiers
* **Zenodo Research Repository (DOI):** [10.5281/zenodo.21719175](https://doi.org/10.5281/zenodo.21719175)
* **Lead Investigator ORCID:** [0009-0007-5824-3602](https://orcid.org/0009-0007-5824-3602)
* **LaTeX Academic Source:** Located under `specifications/ptvs-technical-paper/main.tex`

---

## 📜 Intellectual Property & Citation

Published by **Aurema Group L.L.C.** (Delaware, USA).

If you use PTVS v1.0 in your research, infrastructure, or commercial protocol, please cite it as follows:

```bibtex
@techreport{tamarit2026ptvs,
  author       = {Tamarit Blay, Aurelio},
  title        = {{Prop Trust Verified Standard (PTVS v1.0): A Deterministic Off-Chain Oracle Framework for Real World Asset (RWA) Tokenization}},
  institution  = {Aurema Group L.L.C.},
  year         = {2026},
  month        = {July},
  doi          = {10.5281/zenodo.21719175},
  url          = {[https://doi.org/10.5281/zenodo.21719175](https://doi.org/10.5281/zenodo.21719175)},
  note         = {arXiv submission ID: 7897765}
}
