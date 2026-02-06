#!/bin/bash

# ===================================================
# 🛡️  RALPH ARCHITECT: COMPATIBLE GATEKEEPER
# ===================================================

# Configuration
THRESHOLD=80
GRADER_SCRIPT="lib/grader.py"
RALPH_LOOP="./ralph_loop.sh"

# 1. ARGUMENT PARSING
if [ -z "$1" ]; then
    echo "❌ Usage: $0 <context_directory>"
    exit 1
fi

CONTEXT_DIR="$1"
# Remove trailing slash safely
CONTEXT_DIR=${CONTEXT_DIR%/}

if [ ! -d "$CONTEXT_DIR" ]; then
    echo "❌ Error: Directory '$CONTEXT_DIR' does not exist."
    exit 1
fi

echo ">> 🧐 Inspecting Context at: $CONTEXT_DIR"
echo "---------------------------------------------------"

# 2. DEFINE FILES (Manual variables instead of associative array)
PRD_FILE="$CONTEXT_DIR/prd.md"
DESIGN_FILE="$CONTEXT_DIR/design.md"
CONTRACT_FILE=""
CONTRACT_TYPE=""

# Search for contract (Proto takes precedence, then YAML)
if [ -n "$(find "$CONTEXT_DIR/contract" -maxdepth 1 -name '*.proto' 2>/dev/null | head -n 1)" ]; then
    CONTRACT_FILE=$(find "$CONTEXT_DIR/contract" -maxdepth 1 -name '*.proto' | head -n 1)
    CONTRACT_TYPE="Contract (Protobuf)"
elif [ -n "$(find "$CONTEXT_DIR/contract" -maxdepth 1 -name '*.yaml' 2>/dev/null | head -n 1)" ]; then
    CONTRACT_FILE=$(find "$CONTEXT_DIR/contract" -maxdepth 1 -name '*.yaml' | head -n 1)
    CONTRACT_TYPE="Contract (OpenAPI)"
elif [ -n "$(find "$CONTEXT_DIR/contract" -maxdepth 1 -name '*.json' 2>/dev/null | head -n 1)" ]; then
    CONTRACT_FILE=$(find "$CONTEXT_DIR/contract" -maxdepth 1 -name '*.json' | head -n 1)
    CONTRACT_TYPE="Contract (JSON)"
fi

FAIL_COUNT=0

# 3. GRADING FUNCTION
grade_file() {
    local file_path="$1"
    local doc_type="$2"
    
    if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
        echo "❌ MISSING: $doc_type"
        if [ -n "$file_path" ]; then echo "   (looked at: $file_path)"; fi
        FAIL_COUNT=$((FAIL_COUNT+1))
        return
    fi

    echo -n ">> ⚖️  Grading $doc_type... "
    
    # Call Python Grader
    GRADER_OUTPUT=$(python3 "$GRADER_SCRIPT" "$file_path" "$doc_type")
    
    # Parse Score
    SCORE=$(echo "$GRADER_OUTPUT" | jq '.score')
    
    # Check if jq failed (e.g. invalid json)
    if [ -z "$SCORE" ] || [ "$SCORE" = "null" ]; then
         echo "⚠️  ERROR PARSING GRADER OUTPUT"
         echo "Raw output: $GRADER_OUTPUT"
         FAIL_COUNT=$((FAIL_COUNT+1))
         return
    fi

    if [ "$SCORE" -ge "$THRESHOLD" ]; then
        echo "✅ PASS ($SCORE%)"
    else
        echo "⛔ FAIL ($SCORE%)"
        echo "   Reason: $(echo "$GRADER_OUTPUT" | jq -r '.reasoning')"
        echo "   Critical Gaps:"
        echo "$(echo "$GRADER_OUTPUT" | jq -r '.gaps[]' 2>/dev/null | sed 's/^/- /')"
        echo "   ------------------------"
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
}

# 4. EXECUTE CHECKS
grade_file "$PRD_FILE" "PRD"
grade_file "$DESIGN_FILE" "Design Document"

if [ -z "$CONTRACT_FILE" ]; then
    echo "❌ FATAL: No API Contract found in $CONTEXT_DIR/contract/"
    FAIL_COUNT=$((FAIL_COUNT+1))
else
    grade_file "$CONTRACT_FILE" "$CONTRACT_TYPE"
fi

# 5. DECISION
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "---------------------------------------------------"
    echo "🚫 GATEKEEPER REJECTED LAUNCH."
    echo "   $FAIL_COUNT documents failed checks."
    exit 1
fi

# 6. LAUNCH
echo "---------------------------------------------------"
echo ">> 🚀 All systems GO. Quality Threshold Met."
echo ">> 🧬 Fusing Context..."

CONTEXT_BUFFER=".ralph_context_fused.md"
echo "# MISSION CONTEXT" > "$CONTEXT_BUFFER"

echo "## PRD" >> "$CONTEXT_BUFFER"
cat "$PRD_FILE" >> "$CONTEXT_BUFFER"
echo -e "\n" >> "$CONTEXT_BUFFER"

echo "## DESIGN" >> "$CONTEXT_BUFFER"
cat "$DESIGN_FILE" >> "$CONTEXT_BUFFER"
echo -e "\n" >> "$CONTEXT_BUFFER"

echo "## CONTRACT" >> "$CONTEXT_BUFFER"
cat "$CONTRACT_FILE" >> "$CONTEXT_BUFFER"
echo -e "\n" >> "$CONTEXT_BUFFER"

echo ">> Launching Ralph..."
# $RALPH_LOOP "$(cat "$CONTEXT_BUFFER")"
# For testing:
echo "(Simulation) Ralph launched with $(wc -l < "$CONTEXT_BUFFER") lines of context."
