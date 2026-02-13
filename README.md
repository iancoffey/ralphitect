# Ralphitect

Ralphitect is a governed AI eng workflow that forced focus on PRD, design and spec quality.

The **Architect** script validates your PRD and Design docs for technical rigor before handing them off to **Ralph**, an autonomous agent that builds the software iteratively.

Requires a "human engineer-in-the-loop" command center where the **root README.md** acts as the persistent memory. The workflow enforces a strict **stateful loop**: Ralph reads the current TODOs, executes a task, commits the code, and checks off the item in the README before the next turn.

```text
   1. DEFINE           2. VALIDATE             3. BUILD LOOP
+-------------+     +-------------+     +------------------------+
| specs/      |     | ./architect |     | ./ralph_loop           |
|  - prd.md   | --> |  (Grader)   | --> |  1. Read Context       |<--+
|  - design   |     |             |     |  2. Code & Verify      |   |
+-------------+     +-------------+     |  3. Auto-Git Commit    |   |
       ^                   |            |  4. Update Status      |   |
       |                   v            +-----------+------------+   |
       └────────── (Reject / Improve)               |                |
                                                    v                |
                                          +--------------------+     |
                                          |   ROOT README.md   |     |
                                          | [ ] Todo Item 1    |     |
                                          | [x] Todo Item 2    |-----+
                                          +--------------------+

```
