#!/bin/bash

# ===================================================
# ♾️  RALPH LOOP: AUTONOMOUS BUILDER (Git-Backed)
# ===================================================

CONTEXT="$1"
MANUAL_DIR="$2"
LOG_FILE="ralph_session.log"

# 1. INPUT VALIDATION
if [ -z "$CONTEXT" ]; then
    echo "❌ Error: Context (Arg 1) is missing."
    echo "Usage: ./bin/ralph_loop.sh <context_string> [optional_target_dir]"
    exit 1
fi

if ! command -v claude &> /dev/null; then
    echo "❌ Error: 'claude' CLI not found. (npm install -g @anthropic-ai/claude-code)"
    exit 1
fi

# 2. WORKSPACE RESOLUTION
if [ -n "$MANUAL_DIR" ]; then
    # Case A: User provided a specific path
    TARGET_DIR="$MANUAL_DIR"
    echo ">> 📂 Using specified directory: $TARGET_DIR"
else
    # Case B: Auto-generate name from Mission Context
    PROJECT_NAME=$(echo "$CONTEXT" | grep -iE "^(Project|Mission|Feature|Task):" | head -n 1 | cut -d: -f2 | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]' | sed 's/^_*//;s/_*$//')
    
    if [ -z "$PROJECT_NAME" ]; then
        TARGET_DIR="ralph_mission_$(date +%Y%m%d_%H%M%S)"
    else
        TARGET_DIR="ralph_${PROJECT_NAME}"
    fi
    echo ">> 📂 Auto-created workspace: ./$TARGET_DIR"
fi

# Create and Enter Workspace
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || exit 1
CURRENT_DIR=$(pwd)

# 3. GIT INITIALIZATION (The Safety Net)
if [ ! -d ".git" ]; then
    echo ">> 🛡️  Initializing Git Repository..."
    git init -q
    
    # Create a sensible .gitignore
    if [ ! -f ".gitignore" ]; then
        cat <<EOF > .gitignore
.DS_Store
node_modules/
__pycache__/
*.log
.env
EOF
    fi
    
    git add .gitignore
    git commit -m "chore: project initialization" -q
else
    echo ">> 🛡️  Git Repository detected. Changes will be tracked."
fi

# 4. START SESSION
echo "--- MISSION START: $(date) ---" >> "$LOG_FILE"
echo "==================================================="
echo "       ♾️  RALPH LOOP (Workspace: $(basename "$CURRENT_DIR"))"
echo "==================================================="

# The "God Context" - This is the Seed
CURRENT_PROMPT="
MISSION CONTEXT:
$CONTEXT

INSTRUCTIONS:
1. You are Ralph, a Senior Engineer.
2. INTERNALIZE this context.
3. You are working in: $CURRENT_DIR
4. Output your plan for step 1.
"

TURN=1

# 5. THE INFINITE LOOP
while true; do
    echo "---------------------------------------------------"
    echo ">> 🤖 Ralph is working (Turn $TURN)..."
    echo "---------------------------------------------------"
    
    # Log Prompt
    echo "[TURN $TURN] PROMPT: ${CURRENT_PROMPT:0:100}..." >> "$LOG_FILE"

    # EXECUTE CLAUDE (The Builder)
    # Added: --dangerously-skip-permissions to prevent hanging on tool use
    RESPONSE=$(claude -p "$CURRENT_PROMPT" --dangerously-skip-permissions)
    
    echo "$RESPONSE"
    echo "---------------------------------------------------"
    echo "[TURN $TURN] RESPONSE: $RESPONSE" >> "$LOG_FILE"

    # ===================================================
    # 🧠 INTELLIGENT AUTO-COMMIT
    # ===================================================
    
    # Check for uncommitted changes (staged or unstaged)
    if [ -n "$(git status --porcelain)" ]; then
        echo ">> 💾 Changes detected. Generating smart commit message..."
        
        # Stage all changes
        git add .
        
        # Get the diff stats for the AI to analyze
        DIFF_CONTEXT=$(git diff --cached --stat)
        
        # Ask Claude to write the commit message
        COMMIT_GEN_PROMPT="Based on this git diff summary, write a single line 'Conventional Commit' message (e.g., 'feat: add retry logic' or 'fix: typo in schema'). Output ONLY the message. No quotes.
        
DIFF SUMMARY:
$DIFF_CONTEXT"

        # Added: --dangerously-skip-permissions here too
        COMMIT_MSG=$(claude -p "$COMMIT_GEN_PROMPT" --dangerously-skip-permissions)
        
        # Fallback safety if Claude returns empty string or fails
        if [ -z "$COMMIT_MSG" ]; then COMMIT_MSG="wip: update (turn $TURN)"; fi
        
        # Clean up any potential quotes output by the LLM
        COMMIT_MSG=$(echo "$COMMIT_MSG" | tr -d '"' | tr -d "'")

        # Execute Commit
        git commit -m "$COMMIT_MSG" -q
        
        echo "   ✅ Git Commit: $COMMIT_MSG"
    else
        echo ">> (No file changes this turn)"
    fi

    # ===================================================

    # HUMAN COMMAND CENTER
    echo ">> 🎤 COMMAND CENTER (Turn $TURN):"
    echo "   [Enter] = 'Proceed / Verify' (Auto-Pilot)"
    echo "   [Type]  = Inject specific instructions"
    echo "   [x]     = Exit"
    
    # Added: < /dev/tty to prevent Input/output error
    read -r -p ">> " USER_INPUT < /dev/tty

    if [[ "$USER_INPUT" == "x" ]]; then
        echo ">> Exiting. Repository saved at: $CURRENT_DIR"
        exit 0
    elif [[ -z "$USER_INPUT" ]]; then
        CURRENT_PROMPT="Proceed. Verify your last step or move to the next."
    else
        CURRENT_PROMPT="$USER_INPUT"
    fi
    
    ((TURN++))
done
