---
name: quarkus-dev
description: 'Run and control a local Quarkus dev session with readiness probes, pid tracking, and safe shutdown. Use before local URL smoke tests, Postman/Newman runs, or live debugging.'
argument-hint: "Action + target — e.g. 'start service-a on 8080', 'wait until ready on 8081', 'stop local dev session'"
user-invocable: false
---

# Quarkus Dev Session

## When To Use
- Before calling local endpoints when you do not know whether the app is already running.
- When a task requires a reproducible local dev session with readiness checks.
- Before Postman/Newman or scripted smoke runs.
- When you need to stop or inspect a dev session without guessing the process state.

## Skill Assets

- [Dev-session script](./scripts/quarkus-dev-session.ps1)
- [Guardrails](./references/guardrails.md)
- [Session template](./assets/dev-session.template.json)

## Standard Procedure

1. Prefer an existing workspace task first if one already starts the right module.
2. If no suitable task exists, start Quarkus with the script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/skills/quarkus-dev/scripts/quarkus-dev-session.ps1 \
  -Action start \
  -ServiceDir .\service-a \
  -Port 8080
```

3. Wait for readiness explicitly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/skills/quarkus-dev/scripts/quarkus-dev-session.ps1 \
  -Action wait \
  -ServiceDir .\service-a \
  -Port 8080 \
  -TimeoutSeconds 90
```

4. Use `fetch-api` or `postman-collections` only after `/q/health/ready` is `UP`.
5. When the work ends, stop the session using the same script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/skills/quarkus-dev/scripts/quarkus-dev-session.ps1 \
  -Action stop \
  -ServiceDir .\service-a
```

## Expected Behavior

- Startup is tracked through a pid file local to the service directory.
- Readiness is verified via `/q/health/ready`, not only by TCP port reachability.
- Console output is redirected to `target/quarkus-dev-console.log` and `target/quarkus-dev-error.log`.
- When readiness fails, the script returns a log excerpt so the agent can diagnose without asking the user.

## Operating Notes

- Use one dev session per port.
- Reuse an existing tracked session instead of spawning duplicates.
- If the service uses a custom root path, keep the health path at `/q/health/ready` unless the service overrides it.
- For a repo-specific task runner, the script is the fallback, not the first choice.