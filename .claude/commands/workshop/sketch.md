name: Sketch Change
description: Create a new unit of work and generate all four artifacts

The fast path — sketch the whole piece before building. Follow these steps:

1. Ask the user what they want to build or change. Get a clear description.

2. Derive a kebab-case, verb-led name from their description (e.g., `add-dark-mode`, `fix-login-redirect`, `refactor-api-client`).

3. Create the change directory:
   ```
   mkdir -p workshop/active/<name>
   ```

4. Generate **intent.md** — why this change is needed:
   - Cover motivation, scope, approach, and impact
   - Write to `workshop/active/<name>/intent.md`

5. Generate **requirements/** — what the system needs to do:
   - Organize by capability (e.g., `requirements/ui/req.md`, `requirements/auth/req.md`)
   - Use delta format with ADDED/MODIFIED/REMOVED sections
   - Every requirement needs at least one Given/When/Then scenario
   - Create directories: `mkdir -p workshop/active/<name>/requirements/<capability>`
   - Write each file as `req.md` inside its capability directory

6. Generate **design.md** — how to implement it:
   - Cover technical approach, component structure, data flow, and tradeoffs
   - Reference intent and requirements for context
   - Write to `workshop/active/<name>/design.md`

7. Generate **tasks.md** — implementation checklist:
   - Derive ordered tasks from the design
   - Use checkbox format (`- [ ]`) grouped under numbered sections
   - Each task should be completable in one focused session
   - Write to `workshop/active/<name>/tasks.md`

8. Confirm all artifacts were created and suggest running `/workshop:build` to start implementation.

Important:
- Follow the artifact dependency order: intent → requirements → design → tasks
- Read completed artifacts for context when writing later ones
- Name capabilities after what the system does, not what the change is (e.g., `ui/`, not `dark-mode/`)
- Keep bug fix artifacts naturally lighter than feature artifacts
