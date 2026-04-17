# Quarkus Infinispan Hot Rod + ProtoStream Guardrails

- Use ProtoStream for shared remote cache payloads; do not standardize on JSON envelopes in `RemoteCache<String, String>`.
- Keep cache keys deterministic and server-owned.
- Do not expose cache toggles or override flags in the public REST contract.
- Separate lookup caches from command-result caches.
- Do not cache transient failures as if they were valid data.
- Add metrics and logs for cache hit, miss, bypass, serialization error, and remote unavailability.
- Prefer precise invalidation over broad wildcard eviction when domain scope is known.