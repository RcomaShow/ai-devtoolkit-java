# Postman Collections Guardrails

- Keep bearer tokens, passwords, and gateway URLs in variables or environment files, never hardcoded in collections.
- Default to smoke-safe checks: exact business dataset assertions should be opt-in.
- Every request should define an expected status code explicitly.
- Prefer one request catalog per feature area instead of giant mixed collections.
- Use the same headers and body shapes as the real API contract; do not invent payload fields that the service does not accept.
- For local-vs-remote comparison suites, label remote requests clearly to avoid accidental destructive runs.