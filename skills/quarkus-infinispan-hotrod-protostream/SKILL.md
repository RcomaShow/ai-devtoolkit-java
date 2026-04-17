---
name: quarkus-infinispan-hotrod-protostream
description: 'Patterns for Quarkus 3.x remote Infinispan caches over Hot Rod using ProtoStream/Protobuf serialization, normalized keys, and cache-aside semantics.'
argument-hint: "Cache task — e.g. 'migrate JSON cache to ProtoStream', 'design invalidation policy', 'review Hot Rod serialization'"
user-invocable: false
---

# Quarkus Infinispan Hot Rod + ProtoStream

Use this skill when a Quarkus service reads or writes shared remote caches through Hot Rod and the cache payload must remain stable, typed, cross-node safe, and evolvable.

---

## When To Load This Skill

- migrating `RemoteCache<String, String>` payloads to typed values
- introducing a new shared remote cache
- designing a key strategy for request-derived lookups
- reviewing TTL, invalidation, and negative caching rules
- removing ad hoc JSON envelopes or class-name-based payloads
- planning rolling schema evolution for cached values

---

## Core Rules

1. Prefer typed cache values over stringified JSON payloads.
2. Use ProtoStream/Protobuf for shared remote payloads.
3. Keep key construction deterministic, normalized, and reusable.
4. Separate cache design for immutable lookup data and volatile command-side projections.
5. Treat cache choice as a server concern, not a public API flag.

---

## Recommended Architecture

| Concern | Preferred pattern |
|---|---|
| cache client | `RemoteCache<K, V>` via Hot Rod |
| serialization | ProtoStream with explicit schema and field numbering |
| key format | canonical builder with trimmed values, sorted collections, and stable namespace |
| read strategy | cache-aside |
| write strategy | put only after successful load and normalization |
| invalidation | explicit domain-scope invalidation on mutation |
| observability | separate metrics for hit, miss, bypass, serialization error, remote unavailable |

---

## Migration Path From JSON Payloads

1. Inventory each existing remote cache and classify shared versus local-only data.
2. Define a typed value model per cache family.
3. Reserve stable field numbers in ProtoStream schemas.
4. Register a `SerializationContextInitializer` for the value types.
5. Introduce typed read/write paths before removing the legacy JSON envelope.
6. Where rollout risk exists, use a short dual-read or dual-write migration window.
7. Remove class-name-in-payload serialization once all readers are aligned.

---

## Read And Write Best Practices

- Read once per request and reuse the loaded object in downstream logic.
- Normalize all request-derived key parts before generating the cache key.
- Sort list inputs used in keys, such as action lists or REMI lists, before building the key.
- Cache only values that are semantically safe to reuse.
- Do not cache transient HTTP failures, timeouts, or serialization exceptions.
- Use negative caching only for deterministic `not found` results and only with very short TTL.
- Prefer one typed cache object per logical lookup over multiple fragmented field-level entries.
- When multiple lookups share the same time window and REMI scope, batch the source load before writing cache entries.

---

## Schema Design Guardrails

- Keep field numbers stable forever once published.
- Add fields compatibly; do not repurpose existing numbers.
- Encode enums explicitly and keep unknown values survivable.
- Model nullability deliberately; do not infer it from missing JSON properties.
- Keep cache value classes focused on cache transport concerns, not on entity identity leaks.

---

## Anti-Patterns To Reject

- `RemoteCache<String, String>` with nested JSON and embedded class name as long-term design
- cache keys that depend on client ordering when the server owns the business ordering
- caching command conflicts or validation failures as reusable domain state
- mixing local and remote cache for the same shared data without a measured reason
- wildcard invalidation used as the default when a precise domain scope is available

---

## Related Skills

- `quarkus-backend`
- `quarkus-observability`
- `jsf-quarkus-port-alignment`

---

## Skill Assets

- `references/guardrails.md`