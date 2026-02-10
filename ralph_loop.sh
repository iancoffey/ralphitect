#!/bin/bash

# ===================================================
# ♾️  RALPH LOOP: THE PERSISTENT SESSION
# ===================================================

CONTEXT="$1"

if [ -z "$CONTEXT" ]; then
    echo "❌ Error: Context missing."
    exit 1
fi

# 1. SETUP SESSION
# We use a temp file to track the conversation logic if needed,
# but primarily we rely on the CLI's current working directory session.
# We start by seeding the context.

echo "==================================================="
echo "       ♾️  ENTERING RALPH LOOP"
echo "==================================================="
echo ">> Seeding Mission Context..."

# We construct the "System Prompt"
SEED_PROMPT="
MISSION CONTEXT:
$CONTEXT

INSTRUCTIONS:
1. You are Ralph, a Principal Engineer.
2. You are in an interactive loop.
3. Acknowledge this context and output your plan for step 1.
4. WAIT for user confirmation before executing.
"

# 2. THE LOOP
# We use a variable to track the 'next message' to send to Claude.
NEXT_PROMPT="$SEED_PROMPT"

while true; do
    echo "---------------------------------------------------"
    echo ">> 🤖 Ralph is thinking..."
    echo "---------------------------------------------------"

    # Call Claude with the prompt.
    # We pipe the output to tee so we see it AND capture it.
    # Note: If 'claude' CLI maintains state in cwd, this works perfectly.
    # If not, we'd need to append history manually. Assuming standard claude-code CLI behavior.
    
    RESPONSE=$(claude -p "$NEXT_PROMPT")
    
    echo "$RESPONSE"
    echo "---------------------------------------------------"

    # 3. USER INTERVENTION
    # The agent has spoken. Now YOU drive.
    echo ">> 🎤 YOUR COMMAND:"
    echo "   [Enter] = 'Proceed / Continue'"
    echo "   [Type]  = Give specific feedback or new instructions"
    echo "   [x]     = Exit Loop"
    
    read -r -p ">> " USER_INPUT

    if [[ "$USER_INPUT" == "x" ]]; then
        echo ">> Exiting Ralph Loop."
        exit 0
    elif [[ -z "$USER_INPUT" ]]; then
        # Default action: Tell the agent to continue
        NEXT_PROMPT="Proceed with the next step. Show me the code or execution result."
    else
        # User gave specific instructions
        NEXT_PROMPT="$USER_INPUT"
    fi

    # Optional: Add specific "Autonomous" triggers here
    # e.g. check if RESPONSE contains "EXECUTE:" and run it automatically.
done
