# Git Atomic Commit Guardrails

- One commit must represent one logical change.
- Never mix structural refactors and new behavior in the same commit unless inseparable.
- Do not stage generated noise unrelated to the task.
- Ensure compile and test checks are green before committing.