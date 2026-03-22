name: Inspect Change
description: Verify that the implementation matches requirements and design

Review the completed implementation against the workshop artifacts. Reports on completeness, correctness, coherence, and warnings.

1. Identify which change to inspect:
   - If the user specifies one, use that
   - Otherwise, list directories in `workshop/active/` and pick one with tasks
   - If multiple exist, ask the user

2. Read all artifacts:
   - `workshop/active/<name>/intent.md`
   - `workshop/active/<name>/requirements/` (all req.md files)
   - `workshop/active/<name>/design.md`
   - `workshop/active/<name>/tasks.md`

3. Check **completeness**:
   - Are all tasks in tasks.md checked off?
   - Does every requirement have corresponding implementation?
   - Are test tasks included and completed?

4. Check **correctness**:
   - Does the implementation match the requirement scenarios?
   - Are edge cases from Given/When/Then scenarios handled?
   - Are the right files modified per the design?

5. Check **coherence**:
   - Are design decisions reflected in the code?
   - Is naming consistent with design.md?
   - Does the implementation stay within the stated scope?

6. Report findings:
   - Use checkmarks for passing checks, warnings for issues
   - Be specific — reference files, functions, and requirement sections
   - Give a clear verdict: ready to ship, or needs attention

7. If ready, suggest `/workshop:ship`. If issues found, suggest specific fixes.

Important:
- Read actual source code to verify implementation, don't just check task boxes
- Cross-reference requirements with code, not just design with code
- Flag scope creep — implementation beyond what requirements specify
