#!/bin/bash

# ===================================================
# ♾️  RALPH LOOP: EXPLICIT STATE TRACKING
# ===================================================

CONTEXT="$1"
LOG_FILE="ralph_session.log"

if [ -z "$CONTEXT" ]; then
    echo "❌ Error: Context missing."
    exit 1
fi

# 1. INITIALIZATION
# We wipe the log to start fresh for this run
echo "--- NEW MISSION STARTED: $(date) ---" > "$LOG_FILE"

echo "==================================================="
echo "       ♾️  RALPH LOOP (ITERATION 0)"
echo "==================================================="
echo ">> Seeding Mission Context..."

# The First Prompt is the massive "God Context"
CURRENT_PROMPT="
MISSION CONTEXT:
$CONTEXT

INSTRUCTIONS:
1. You are Ralph, a Principal Engineer.
2. INTERNALIZE this context.
3. Output your plan for step 1.
"

TURN=1

# 2. THE LOOP
while true; do
    echo "---------------------------------------------------"
    echo ">> 🤖 Ralph is thinking (Turn $TURN)..."
    echo "---------------------------------------------------"

    # Log what we are sending (for debugging)
    echo "[TURN $TURN] PROMPT: ${CURRENT_PROMPT:0:100}..." >> "$LOG_FILE"

    # EXECUTE CLAUDE
    # -p sends the prompt
    # We rely on the CLI's internal session persistence for context,
    # but we control the *incremental* prompt here.
    RESPONSE=$(claude -p "$CURRENT_PROMPT")
    
    # Check if Claude actually ran or failed
    if [ $? -ne 0 ]; then
        echo "❌ Error: Claude CLI failed. Check your login status."
        exit 1
    fi

    echo "$RESPONSE"
    echo "---------------------------------------------------"
    
    # Log the response
    echo "[TURN $TURN] RESPONSE: $RESPONSE" >> "$LOG_FILE"

    # 3. HUMAN FEEDBACK LAYER
    echo ">> 🎤 COMMAND CENTER (Turn $TURN):"
    echo "   [Enter] = 'Proceed / Continue' (Auto-Approval)"
    echo "   [Type]  = Inject new constraints or feedback"
    echo "   [x]     = Exit Mission"
    
    read -r -p ">> " USER_INPUT

    if [[ "$USER_INPUT" == "x" ]]; then
        echo ">> Exiting Ralph Loop. Session log saved to $LOG_FILE"
        exit 0
    elif [[ -z "$USER_INPUT" ]]; then
        # The user hit Enter. The prompt becomes a generic "Go ahead"
        CURRENT_PROMPT="Proceed with the next step. Execute and verify."
    else
        # The user gave specific instructions.
        CURRENT_PROMPT="$USER_INPUT"
    fi
    
    # Iterate
    ((TURN++))
done
