---
name: git-atomic-commit
description: 'Protocol for producing clean, atomic git commits after each completed implementation step. Load this after any implementation step that modifies files.'
argument-hint: "Commit point reached — e.g. 'after creating service', 'after adding endpoint', 'after writing tests'"
user-invocable: false
---

# Git Atomic Commit Protocol

> One commit = one logical change. Compilation green. Tests pass. No mixed concerns.

---

## What Makes a Commit Atomic

| Criterion | Correct | Wrong |
|-----------|---------|-------|
| Scope | One logical unit (e.g. "add POST /nominas endpoint") | Mix of multiple features or unrelated fixes |
| State | Compilation green, all tests pass | WIP, broken imports, red tests |
| Message | Describes the *why*, conventional format | "changes", "wip", "various fixes" |
| Files | Only files needed for this change | Unrelated formatting, IDE config, generated classes |

---

## Conventional Commit Format

```
<type>(<scope>): <subject>

[optional body — explain WHY, not what]

[optional footer: Co-Authored-By, Closes #xxx]
```

### Types

| Type | When to use |
|------|-------------|
| `feat` | New feature, endpoint, service, or domain model |
| `fix` | Bug fix |
| `refactor` | Code restructure with no behaviour change |
| `test` | Add or modify tests only |
| `docs` | Documentation changes only |
| `chore` | Build config, dependencies, tooling, migrations |
| `perf` | Performance improvement |

### Scope
Use the domain or layer: `(nominas)`, `(api)`, `(persistence)`, `(mapper)`, `(auth)`.

### Examples

```bash
feat(nominas): add POST /api/v1/nominas endpoint with Bean Validation

Implements NominaResource.create() delegating to NominaService.
Service persists via NominaPanacheRepository and returns NominaDto.

Closes #42
```

```bash
test(nominas): add 100% branch coverage for NominaService.create

Covers: happy path, duplicate code conflict, invalid date range,
repository throws unexpected exception.
```

```bash
fix(persistence): correct NominaAclTranslator null handling on update path

entity.id was not checked before calling entityRepo.merge(),
causing a persist-instead-of-merge bug on entities with null id.
```

---

## Pre-Commit Checklist

Run these before `git commit`:

- [ ] `./mvnw compile` exits 0 — zero compilation errors
- [ ] `./mvnw test` exits 0 — all tests green
- [ ] `git diff --stat` shows only files relevant to this commit
- [ ] No `TODO`, `FIXME`, or `System.out.println` left in changed files
- [ ] MapStruct mapper compiled without `unmappedTargetPolicy` errors
- [ ] No `{Entity}Entity` class referenced outside `data/` package
- [ ] No `@Inject` field injection added — constructor only

---

## Commit Granularity Rules

| What was completed | Commit count | Message pattern |
|-------------------|-------------|-----------------|
| Panache entity + EntityRepository + ACL Translator + Port impl | 1 | `feat(persistence): add {Entity} persistence layer` |
| Domain model + port interface + application service + mapper | 1 | `feat(service): add {Entity}Service with domain model and mapper` |
| REST resource + DTOs + error mapper | 1 | `feat(api): add {Entity}Resource CRUD endpoints` |
| Test class for one production class | 1 | `test({scope}): add branch coverage for {ClassName}` |
| Flyway schema migration | 1 | `chore(db): add V{n}__create_T_{ENTITY} table` |
| Full small feature (< 5 files, single concern) | 1 | `feat({scope}): add {feature name}` |

**Rule:** If `git diff --stat` shows > 10 files, split into multiple commits by layer before committing.

---

## Git Commands

```bash
# Always inspect status first — never commit blindly
git status
git diff --stat

# Stage only the files for this commit (never git add -A or git add .)
git add src/main/java/com/company/domain/service/NominaService.java
git add src/main/java/com/company/domain/mapping/NominaMapper.java
git add src/test/java/com/company/domain/service/NominaServiceTest.java

# Verify exactly what will be committed
git diff --staged --stat

# Commit with conventional message (use heredoc for multiline)
git commit -m "$(cat <<'EOF'
feat(nominas): add NominaService with create/update/delete

Orchestrates domain operations via NominaRepository port.
All write operations are @Transactional; reads are non-transactional.
EOF
)"
```

---

## When to Split a Commit

Split into two commits when a single `git add .` would include:
- Production code + infrastructure (e.g., entity AND Flyway migration)
- Multiple independent domain features touched in the same session
- Test code that significantly outweighs its production counterpart

```bash
# Example: two separate commits for entity and migration
git add src/main/java/.../NominaEntity.java ...ACL... ...Repository...
git commit -m "feat(persistence): add Nomina persistence layer"

git add src/main/resources/db/migration/V5__create_T_NOMINA.sql
git commit -m "chore(db): add V5 migration for T_NOMINA table"
```

---

## Rules

- **Never** `git add .` — always stage by explicit path.
- **Never** commit with red tests. Use `@Disabled("TICKET-123: reason")` only as a deliberate deferral.
- **Never** squash pushed commits — squash only local commits before the first push.
- **Always** verify `git diff --staged --stat` before committing.
