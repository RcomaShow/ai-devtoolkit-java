# JSF To Quarkus Port Alignment Guardrails

- Keep proven legacy semantics explicit before optimizing or simplifying them.
- Do not collapse distinct legacy pre-checks into one API if their business meaning differs.
- Keep public API vocabulary aligned with the domain language.
- Treat missing external integrations as TODO or fail-fast conditions, not as mocked business parity.
- If a legacy branch exists, either port it or reject it explicitly.
- A legacy facade is acceptable only if it delegates to the canonical server-side flow.
- Classify every gap before fixing it: internal parity, external TODO, intentional divergence, or blocked by contract.