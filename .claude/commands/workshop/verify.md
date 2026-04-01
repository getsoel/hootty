---
name: Verify Change
description: Verify implementation matches specs and design
---

Verify that the implementation of a workshop-driven change matches its specifications and design.

1. Run `workshop status --json` to find the active change and check artifact status.

2. Read all artifacts:
   - `workshop/changes/<name>/proposal.md`
   - `workshop/changes/<name>/specs/` (all spec files)
   - `workshop/changes/<name>/design.md`
   - `workshop/changes/<name>/tasks.md`

3. Check three dimensions:

   **Completeness**
   - All tasks in tasks.md are checked off
   - All requirements in specs are implemented
   - All scenarios in specs have corresponding test coverage

   **Correctness**
   - Implementation matches spec intent (not just letter)
   - Edge cases from specs are handled
   - Error conditions are handled appropriately

   **Coherence**
   - Design decisions from design.md are reflected in the implementation
   - Code patterns are consistent
   - No contradictions between implementation and specs

4. Report findings as a checklist:
   - PASS: requirement is correctly implemented
   - FAIL: requirement is missing or incorrectly implemented
   - WARN: implementation exists but may not fully match spec

5. Suggest fixes for any FAIL or WARN items.

Rules:
- Do NOT modify any code — this is a review-only mode
- Be thorough — check every requirement and scenario
- Reference specific spec requirements and code locations
