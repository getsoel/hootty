---
name: Explore
description: Investigate and explore without implementing
---

Help the user explore and investigate their codebase or workshop state. This is a free-form mode for thinking, diagramming, and understanding.

1. Run `workshop status` to show current workshop state.

2. If there is an active change, claim it for this session:
   ```
   workshop claim --change <name>
   ```

3. Based on the user's question, explore the codebase, read specs, and investigate.

4. Share your findings as conversation — do NOT implement anything or modify code.

Rules:
- Do NOT modify any source code files
- Do NOT update task checkboxes
- Do NOT create or modify spec artifacts unless the user explicitly asks
- Focus on understanding, analysis, and discussion
- You may read any files, search the codebase, and analyze architecture
- If the change has a `scope`, prioritize exploring within that subfolder
