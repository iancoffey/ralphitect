# Ralphitect

Ralphitect is a governed AI engineering workflow that turns Markdown specifications into production-ready code.

The **Architect** script validates your PRD and Design docs for technical rigor before handing them off to **Ralph**, an autonomous agent that builds the software iteratively.

Requies a "human engineer-in-the-loop" command center and performs automatic, AI-generated Git commits after every turn to ensure safety and clean history.

```text
   1. DEFINE           2. VALIDATE             3. BUILD LOOP
+-------------+     +-------------+     +------------------------+
| specs/      |     | ./architect |     | ./ralph_loop           |
|  - prd.md   | --> |  (Grader)   | --> |  1. Plan & Code        |
|  - design   |     |             |     |  2. Human Verify       |
+-------------+     +-------------+     |  3. Auto-Git Commit ↻  |
       ^                   |            +------------------------+
       |                   v                        |
       └────────── (Reject / Improve)               v
                                             [Running Software]
