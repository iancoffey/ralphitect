#!/bin/bash

# ===================================================
# 🛡️  RALPH ARCHITECT: THE ADVISOR (Soft-Block)
# ===================================================

# Configuration
THRESHOLD=80
GRADER_SCRIPT="lib/grader.py"
RALPH_LOOP="./ralph_loop.sh"
CACHE_DIR=".architect_cache"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Helper: Cross-platform SHA256
function get_file_hash() {
    if command -v shasum &> /dev/null; then
        shasum -a 256 "$1" | awk '{print $1}' # macOS
    else
        sha256sum "$1" | awk '{print $1}'     # Linux
    fi
}

# 1. ARGUMENT PARSING
if [ -z "$1" ]; then
    echo "❌ Usage: $0 <context_directory>"
    exit 1
fi

CONTEXT_DIR="$1"
CONTEXT_DIR=${CONTEXT_DIR%/} # Remove trailing slash

if [ ! -d "$CONTEXT_DIR" ]; then
    echo "❌ Error: Directory '$CONTEXT_DIR' does not exist."
    exit 1
fi

echo ">> 🧐 Inspecting Context at: $CONTEXT_DIR"
echo "---------------------------------------------------"

# 2. DEFINE FILES
PRD_FILE="$CONTEXT_DIR/prd.md"
DESIGN_FILE="$CONTEXT_DIR/design.md"
CONTRACT_FILE=""
CONTRACT_TYPE="None"

# Attempt to find contract
if [ -n "$(find "$CONTEXT_DIR/contract" -maxdepth 1 -name '*.proto' 2>/dev/null | head -n 1)" ]; then
    CONTRACT_FILE=$(find "$CONTEXT_DIR/contract" -maxdepth 1 -name '*.proto' | head -n 1)
    CONTRACT_TYPE="Protobuf"
elif [ -n "$(find "$CONTEXT_DIR/contract" -maxdepth 1 -name '*.yaml' 2>/dev/null | head -n 1)" ]; then
    CONTRACT_FILE=$(find "$CONTEXT_DIR/contract" -maxdepth 1 -name '*.yaml' | head -n 1)
    CONTRACT_TYPE="OpenAPI"
elif [ -n "$(find "$CONTEXT_DIR/contract" -maxdepth 1 -name '*.json' 2>/dev/null | head -n 1)" ]; then
    CONTRACT_FILE=$(find "$CONTEXT_DIR/contract" -maxdepth 1 -name '*.json' | head -n 1)
    CONTRACT_TYPE="JSON"
fi

FAIL_COUNT=0

# 3. GRADING FUNCTION
grade_file() {
    local file_path="$1"
    local doc_type="$2"
    
    # CASE: File Missing
    if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
        echo ">> ⚖️  Grading $doc_type... ❌ MISSING"
        echo "   (Ralph will struggle without this context)"
        FAIL_COUNT=$((FAIL_COUNT+1))
        return
    fi

    echo -n ">> ⚖️  Grading $doc_type... "

    # --- CACHING LOGIC START ---
    local safe_name=$(basename "$file_path" | sed 's/[^a-zA-Z0-9]/_/g')
    local hash_file="$CACHE_DIR/${safe_name}.sha"
    local result_file="$CACHE_DIR/${safe_name}.json"
    local current_hash=$(get_file_hash "$file_path")
    local use_cache=false

    if [ -f "$hash_file" ] && [ -f "$result_file" ]; then
        local cached_hash=$(cat "$hash_file")
        if [ "$current_hash" == "$cached_hash" ]; then
            use_cache=true
        fi
    fi

    if [ "$use_cache" = true ]; then
        echo -n "(Cached) "
        GRADER_OUTPUT=$(cat "$result_file")
    else
        # Call Python Grader
        GRADER_OUTPUT=$(python3 "$GRADER_SCRIPT" "$file_path" "$doc_type")
        
        # Write to Cache
        echo "$GRADER_OUTPUT" > "$result_file"
        echo "$current_hash" > "$hash_file"
    fi
    # --- CACHING LOGIC END ---
    
    # Parse Score
    SCORE=$(echo "$GRADER_OUTPUT" | jq '.score')
    REASON=$(echo "$GRADER_OUTPUT" | jq -r '.reasoning')
    
    # Check for parser failure
    if [ -z "$SCORE" ] || [ "$SCORE" = "null" ]; then
         echo "⚠️  ERROR PARSING GRADER"
         FAIL_COUNT=$((FAIL_COUNT+1))
         return
    fi

    if [ "$SCORE" -ge "$THRESHOLD" ]; then
        echo "✅ PASS ($SCORE%)"
    else
        echo "⛔ FAIL ($SCORE%)"
        echo "   Reason: $REASON"
        echo "   Critical Gaps:"
        # Pretty print the gaps list with bullets
        echo "$GRADER_OUTPUT" | jq -r '.gaps[]' 2>/dev/null | sed 's/^/- /'
        echo "   ------------------------"
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
}

# 4. EXECUTE CHECKS
grade_file "$PRD_FILE" "PRD"
grade_file "$DESIGN_FILE" "Design Document"
grade_file "$CONTRACT_FILE" "Contract ($CONTRACT_TYPE)"

# 5. THE DECISION (Soft Block)
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "=================================================="
    echo "⚠️  GATEKEEPER WARNING: $FAIL_COUNT documents failed quality checks."
    echo "=================================================="
    
    # The Interactive Prompt
    read -p ">> Do you wish to launch Ralph anyway? (y/N) " CHOICE
    
    if [[ ! "$CHOICE" =~ ^[Yy]$ ]]; then
        echo ">> 🚫 Launch Aborted by User."
        exit 1
    fi
    
    echo ">> ⚠️  Overriding Gatekeeper... Proceeding with caution."
else
    echo "=================================================="
    echo ">> ✅ All systems GO. Quality Threshold Met."
    echo "=================================================="
fi

# 6. LAUNCH
echo ">> 🧬 Fusing Context..."

CONTEXT_BUFFER=".ralph_context_fused.md"
echo "# MISSION CONTEXT" > "$CONTEXT_BUFFER"

if [ -f "$PRD_FILE" ]; then
    echo "## PRD" >> "$CONTEXT_BUFFER"
    cat "$PRD_FILE" >> "$CONTEXT_BUFFER"
    echo -e "\n" >> "$CONTEXT_BUFFER"
fi

if [ -f "$DESIGN_FILE" ]; then
    echo "## DESIGN" >> "$CONTEXT_BUFFER"
    cat "$DESIGN_FILE" >> "$CONTEXT_BUFFER"
    echo -e "\n" >> "$CONTEXT_BUFFER"
fi

if [ -f "$CONTRACT_FILE" ]; then
    echo "## CONTRACT" >> "$CONTEXT_BUFFER"
    cat "$CONTRACT_FILE" >> "$CONTEXT_BUFFER"
    echo -e "\n" >> "$CONTEXT_BUFFER"
fi

echo ">> 🚀 Launching Ralph..."
echo "---------------------------------------------------"

# Execute Ralph Loop
$RALPH_LOOP "$(cat "$CONTEXT_BUFFER")"
