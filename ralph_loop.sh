#!/bin/bash

# ===================================================
# 🤖 RALPH LOOP: The Builder
# ===================================================

# 1. INPUT HANDLING
CONTEXT="$1"

if [ -z "$CONTEXT" ]; then
    echo "❌ Error: Ralph Loop requires context to start."
    exit 1
fi

# 2. CHECK DEPENDENCIES
if ! command -v claude &> /dev/null; then
    echo "❌ Error: 'claude' CLI not installed."
    echo "   Run: npm install -g @anthropic-ai/claude-code"
    exit 1
fi

# 3. SESSION INITIALIZATION
echo "==================================================="
echo "       🤖 RALPH AGENT INITIALIZED"
echo "==================================================="
echo ">> Loading Mission Context..."
echo ">> Context Size: $(echo "$CONTEXT" | wc -c) bytes"
echo "---------------------------------------------------"

# 4. THE PROMPT INJECTION
# We wrap the context in a "System Instruction" wrapper to force behavior.
# This ensures Ralph acts like a Senior Dev, not a chat bot.

SYSTEM_WRAPPER="
You are Ralph, a Principal Software Engineer.
You have been given a STRICT Mission Context below.

INSTRUCTIONS:
1. READ the PRD, Design, and Contract.
2. PLAN your execution steps before writing code.
3. EXECUTE the plan using your tools (bash, file writes).
4. VERIFY every step (run tests, check syntax).
5. If the Spec is missing details, ASK the user. Do not guess.

---
MISSION CONTEXT START
$CONTEXT
MISSION CONTEXT END
---

COMMAND:
Acknowledge receipt of this mission plan and propose the first 3 steps you will take to implement the 'Design' defined above.
"

# 5. LAUNCH CLAUDE
# The -p flag seeds the session with our context.
# The agent will start, read the context, and wait for your command or start working.

claude -p "$SYSTEM_WRAPPER"
