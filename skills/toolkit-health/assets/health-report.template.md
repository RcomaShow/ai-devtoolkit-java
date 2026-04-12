# Toolkit Health Report — {date}

## Toolkit Version
- Source: {version from VERSION file}
- Runtime: {version if tracked, or "unversioned"}

## Source↔Runtime Drift
| Asset | Source | Runtime | Status |
|-------|--------|---------|--------|
| {agent/skill} | {present/absent} | {present/absent} | {OK/DRIFT/MISSING} |

## Broken References
| File | Referenced Path | Status |
|------|----------------|--------|
| {file} | {path} | {OK/BROKEN} |

## Orphaned Assets
- {file — reason it appears orphaned}

## Skill Gaps
| Intent or Task Pattern | Current Coverage | Proposed Action |
|----------------------|-----------------|-----------------|
| {pattern} | {none/partial} | {propose skill/extend existing} |

## Catalog Consistency
- Frontmatter issues: {count}
- Public surface: {OK/ISSUE}
- Skill structure: {OK/ISSUE}

## Evolution Proposals
1. {proposal}
2. {proposal}

## Action Items
- [ ] {action}
