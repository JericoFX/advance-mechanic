# AGENTS.md — Global Operating Modes (Project-Agnostic)

This repository uses explicit operating modes. Every agent MUST follow the mode selected in the user prompt.

## 1) Mode Selection (MANDATORY)
The user will start their request with one of these headers:

- `MODE: AUDIT`
- `MODE: PLAN`
- `MODE: FIX`
- `MODE: VALIDATE`

If no header is provided, default to `MODE: AUDIT`.

### No Mode Mixing
You MUST NOT mix modes in a single response.
If you notice you started mixing modes, you MUST:
1) stop,
2) restate the correct mode,
3) continue in that mode only.

---

## 2) Project Profile (Optional, repo-specific)
If the user provides a "Project Profile" in the prompt, treat it as authoritative.
If not provided, infer conservatively and state assumptions.

A Project Profile may include:
- Tech stack (language/framework/runtime)
- Folder layout (src/, packages/, apps/, etc.)
- Build/test tooling
- Code conventions (linting, formatting, typing)
- Target environment (web, backend, game, mobile, embedded)

Do NOT invent details. If unknown, say "assumed" and keep recommendations generic.

---

## MODE: AUDIT — System-level review (No code changes)
### Objective
Assess the codebase/system as a whole for correctness, security, performance, maintainability, and reliability.

### Non-negotiable Rules
1. Do NOT review file-by-file unless requested.
2. First build a global model:
   - architecture boundaries and responsibilities
   - shared utilities/patterns
   - dependency graph & hotspots
   - data flow and state management
   - build/deploy/test posture (if relevant)
3. Findings MUST be grouped by CATEGORY, not by file list.

### Must-cover Categories (adapt to project type)
- Functional correctness / defects
- Security & abuse cases (as applicable)
- Performance & scalability (runtime + build-time)
- Reliability & error handling
- Architecture & maintainability (duplication, boundaries, APIs)
- UX/accessibility (if UI)
- Observability (logging/metrics/tracing) (if backend)
- Build, CI, packaging, dependencies
- Edge cases & operational risks

### Output Format (STRICT)
1. Executive summary (max 10 lines)
2. Critical must-fix issues (highest severity)
3. Systemic refactors (multi-area)
4. Performance/scalability improvements
5. Security/reliability issues
6. Consistency/API/design violations (if applicable)
7. Quick wins (low-risk)
8. Assumptions / unknowns

### Constraints
- Do NOT write code.
- Avoid stylistic nitpicks unless they cause defects, risk, or long-term cost.

---

## MODE: PLAN — Fix plan only (No code)
### Objective
Turn audit findings into an actionable plan with sequencing, risk, and validation approach.

### Non-negotiable Rules
1. Do NOT write code.
2. Group by Severity (Critical/High/Medium/Low) and Scope (Systemic/Localized).
3. Each item MUST include:
   - Root cause
   - Proposed approach (pattern-level)
   - Expected impact
   - Risk level (Low/Medium/High)
   - Validation strategy (tests/checks)

### Output Format (STRICT)
1. Plan overview (goals + sequencing strategy)
2. Backlog (grouped by severity)
3. Implementation phases (Phase 0/1/2…)
4. Risks & guardrails (what not to change)
5. Validation checklist

---

## MODE: FIX — Apply fixes (Controlled implementation)
### Objective
Implement fixes following the plan, prioritizing systemic/high-impact items.

### Non-negotiable Rules
1. Follow the plan order unless a dependency forces reordering (state why).
2. Avoid broad refactors unless explicitly part of the plan.
3. Avoid breaking changes unless explicitly approved.
4. Keep changes reviewable: coherent batches, minimal unrelated edits.
5. If a fix is uncertain, choose the safest option and document tradeoffs.

### Required Fix Workflow (per batch)
1. Scope: which plan items are being fixed
2. Rationale: root cause → solution
3. Patch: relevant diffs/snippets only (avoid dumping entire files)
4. Side effects/risks and compatibility notes
5. Validation steps to run / scenarios to test

### Output Format (STRICT)
1. Fix batch scope (plan items)
2. Changes made (concise)
3. Patch (relevant snippets)
4. Risks / notes
5. Validation steps

---

## MODE: VALIDATE — Verification only (No new features/refactors)
### Objective
Verify that changes resolve the plan/audit findings and did not introduce regressions.

### Non-negotiable Rules
1. Do NOT add new features.
2. Do NOT refactor for cleanliness.
3. Only propose additional fixes if validation shows a clear failure.

### Output Format (STRICT)
1. Validated items (mapped to plan)
2. Method (tests/checks/scenarios)
3. Status (Pass/Fail per item with brief evidence)
4. Remaining gaps + minimal next steps

---

## 3) Global Quality Bar (All modes)
- Prefer system-level reasoning over per-file narration.
- Be explicit about assumptions.
- Prioritize issues by severity and blast radius.
- Keep deliverables actionable (what/why/how/where-to-look, not vague advice).
