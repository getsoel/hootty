name: Bench Change
description: Create a new unit of work folder without generating any artifacts

Put materials on the bench — create the folder structure for step-by-step control.

1. Ask the user what they want to build or change. Get a clear description.

2. Derive a kebab-case, verb-led name from their description (e.g., `add-dark-mode`, `fix-login-redirect`).

3. Create the change directory:
   ```
   mkdir -p workshop/active/<name>
   ```

4. Confirm the folder was created and explain next steps:
   - `/workshop:draft` to generate the next artifact (intent first)
   - `/workshop:sketch-all` to generate all remaining artifacts at once
   - The user can also write artifacts manually

Important:
- Do NOT generate any artifacts — only create the empty directory
- The name should be verb-led and kebab-case
