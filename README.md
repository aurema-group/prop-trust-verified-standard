# Prop Trust Verified Standard (PTVS) v1.0

**A Deterministic Off-Chain Oracle Framework for Real World Asset (RWA) Tokenization**

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24001234.svg)](https://doi.org/10.5281/zenodo.24001234)
[![ORCID](https://img.shields.io/badge/ORCID-0009--0007--5824--3602-green.svg)](https://orcid.org/0009-0007-5824-3602)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

---

## 🛡️ Intellectual Property & Prior Art Notice

This repository contains reference implementations of the **Prop Trust Verified Standard (PTVS) v1.0**. While the code is provided for academic and integrative reference, the underlying architecture, taxonomy, and methodologies are strictly protected intellectual property.

*   **Official Terminology & Prior Art Declaration:** Registered with CERN Zenodo.  
    🔗 **DOI:** [10.5281/zenodo.24001234](https://doi.org/10.5281/zenodo.24001234)
*   **Intellectual Property Registry:** Registered under Spanish Intellectual Property Law (Safe Creative).  
    📜 **Registry No:** `2611067566842` | **Verification Code:** `2611067566842-6LV57H`
*   **Protected Terms:** The terms "PTVS", "QFER" (Qualified Forensic Evidence Record), "RFC-003", "Hollow Token", "PTCE", and "Physical Oracle Gap" are proprietary. Unauthorized commercial use or trademark registration attempts by third parties will be contested using the aforementioned registrations as definitive prior art.

---

## 📑 Technical Paper & Academic References

The complete mathematical, legal, and cryptographic specifications of PTVS v1.0 are published under open-access research licenses:

*   **Title:** Prop Trust Verified Standard (PTVS v1.0): A Deterministic Off-Chain Oracle Framework for Real World Asset (RWA) Tokenization
*   **Author:** Aurelio Tamarit Blay (Principal Researcher, Aurema Group LLC / PropTrust Association)
*   **ORCID:** [0009-0007-5824-3602](https://orcid.org/0009-0007-5824-3602)
*   **Zenodo DOI (Technical Spec):** [10.5281/zenodo.21719175](https://doi.org/10.5281/zenodo.21719175)
*   **Zenodo DOI (Terminology & Prior Art):** [10.5281/zenodo.24001234](https://doi.org/10.5281/zenodo.24001234)
*   **OSF:** https://doi.org/10.17605/OSF.IO/7D2SJ

---

## 🔗 Integration with ERC-3643

PTVS v1.0 fits directly into the ERC-3643 (T-REX) architecture as a specialized Trusted Claim Issuer, bridging Layer-0 physical reality with on-chain compliance:

1.  **Audit Execution:** Certified judicial experts (PTCE) complete physical and title verification under ISO/IEC 17020 standards.
2.  **Claim Issuance:** The PTVS Oracle issues an ONCHAINID Claim containing:
    *   `Claim Topic`: `PTVS_PHYSICAL_VERIFICATION_TOPIC`
    *   `Issuer`: Aurema Group / Prop Trust Verified Node
    *   `Payload Signature`: `keccak256(PTVS_Report_Hash + ExpirationTimestamp + AuditScore)`
3.  **Compliance Verification:** The ERC-3643 Compliance contract checks for a valid, non-expired PTVS Claim via the `isPhysicallyAndLegallyBound()` modifier before allowing token creation or peer-to-peer transfers.
4.  **Circuit Breaker:** In the event of a legal mandate or critical physical pathology, the `freezeByLegalMandate()` function executes a 'Hollow Token' state, protecting institutional liquidity pools.

---

## 📚 Official Documentation & Technical Specifications

The PTVS ecosystem is fully documented across institutional, technical, and academic layers:

### 📘 Institutional & Standard Specifications
*   [ISO-Style Technical Specification (PDF)](specifications/ptvs-technical-specification.pdf)
*   [International Executive Dossier (PDF)](specifications/ptvs-executive-dossier.pdf)

### 🔧 Technical Specifications & ERC-3643 Integration
*   [ERC-3643 Integration Guide & Reference Code](specifications/erc3643-integration/)
*   [Canonical PTVS Claim JSON Schema](specifications/qfer-schema.json)
*   `PTVSClaimInjector.sol` — Reference smart contract implementation for on-chain identity claims.
*   `isPhysicallyAndLegallyBound` — Solidity modifier for transfer validation.
*   `freezeByLegalMandate` — Solidity function for programmatic legal freezing (RFC-003).

### 🎓 Academic Research & Persistent Identifiers
*   LaTeX Academic Source: Located under `specifications/ptvs-technical-paper/main.tex`

---

## 📜 Intellectual Property & Citation

Published by **Aurema Group LLC** (Delaware, USA) and governed by the **PropTrust Association** (Zug, Switzerland).

If you use PTVS v1.0 in your research, infrastructure, or commercial protocol, please cite it as follows:

```bibtex
@techreport{tamarit2026ptvs,
  author       = {Tamarit Blay, Aurelio},
  title        = {{Prop Trust Verified Standard (PTVS v1.0): A Deterministic Off-Chain Oracle Framework for Real World Asset (RWA) Tokenization}},
  institution  = {Aurema Group LLC \& PropTrust Association},
  year         = {2026},
  month        = {November},
  doi          = {10.5281/zenodo.21719175},
  url          = {https://doi.org/10.5281/zenodo.21719175},
  note         = {Supplementary Prior Art \& Terminology Registry: 10.5281/zenodo.24001234}
}


## 🔄 Phase 2 Update: Institutional Governance & Swiss Integration (Nov 2026)
The PTVS v1.0 framework is currently undergoing formal institutionalization with the establishment of the **PropTrust Association (Verein)** in Zug, Switzerland, to serve as the neutral, non-profit governing body of the standard. 

This ensures long-term, jurisdictionally robust governance of the PTCE expert network and the RFC-003 protocol, aligning with the highest standards of Swiss Civil Code (Art. 60-79) and EU regulatory frameworks (MiCA, Basel III).

*All prior art, terminology, and technical blueprints remain immutably anchored under:*
- **Zenodo DOI (Taxonomy):** 10.5281/zenodo.24001234
- **Zenodo DOI (Technical Blueprint):** 10.5281/zenodo.24031701
- **Safe Creative IP Registry:** 2611067566842 (SHA-256: `e1561a13c15259a5c826d94a5dcc5d0e65c1efdaec95f32dcbd0335fa013ff61`)
