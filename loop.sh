# Usage: ./loop.sh [--model model_name] [plan] [max_iterations]
# Examples:
#   ./loop.sh              # Build mode, unlimited iterations
#   ./loop.sh 20           # Build mode, max 20 iterations
#   ./loop.sh plan         # Plan mode, unlimited iterations
#   ./loop.sh plan 5       # Plan mode, max 5 iterations
#   ./loop.sh --model sonnet plan 5

# Parse optional --model flag
USER_MODEL=""
if [[ "$1" == "--model" ]]; then
    USER_MODEL="$2"
    shift 2
fi

# Model shortcuts mapping
case "$USER_MODEL" in
    "opus")          USER_MODEL="lite_anthropic/claude-opus-4-5" ;;
    "sonnet")        USER_MODEL="lite_anthropic/claude-sonnet-4-5" ;;
    "haiku")         USER_MODEL="lite_anthropic/claude-haiku-4-5" ;;
    "gemini-pro")    USER_MODEL="lite_google/gemini-3-pro-preview" ;;
    "gemini-flash")  USER_MODEL="lite_google/gemini-3-flash-preview" ;;
    "gpt-5")         USER_MODEL="lite_openai/gpt-5" ;;
    "gpt-5-mini")    USER_MODEL="lite_openai/gpt-5-mini" ;;
esac

# Parse remaining arguments
if [ "$1" = "plan" ]; then
    # Plan mode
    MODE="plan"
    PROMPT_FILE="PROMPT_plan.md"
    MAX_ITERATIONS=${2:-0}
    MODEL=${USER_MODEL:-"lite_anthropic/claude-opus-4-5"}
elif [[ "$1" =~ ^[0-9]+$ ]]; then
    # Build mode with max iterations
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=$1
    MODEL=${USER_MODEL:-"lite_google/gemini-3-pro-preview"}
else
    # Build mode, unlimited (no arguments or invalid input)
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=0
    MODEL=${USER_MODEL:-"lite_google/gemini-3-pro-preview"}
fi

ITERATION=0
CURRENT_BRANCH=$(git branch --show-current)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode:   $MODE"
echo "Prompt: $PROMPT_FILE"
echo "Model:  $MODEL"
echo "Branch: $CURRENT_BRANCH"
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:    $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify prompt file exists
if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: $PROMPT_FILE not found"
    exit 1
fi

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    # Run Ralph iteration with selected prompt
    # run: Headless mode (non-interactive, reads from stdin)
    # (By default opencode auto-approves all tool calls)
    # --format json: Structured output for logging/monitoring
    # --model: Selected based on mode (Opus for plan, Gemini Pro for build)
    # --log-level DEBUG --print-logs: Detailed execution logging
    cat "$PROMPT_FILE" | opencode run \
        --format json \
        --model "$MODEL" \
        --log-level DEBUG \
        --print-logs

    # Push changes after each iteration
    git push origin "$CURRENT_BRANCH" || {
        echo "Failed to push. Creating remote branch..."
        git push -u origin "$CURRENT_BRANCH"
    }

    ITERATION=$((ITERATION + 1))
    echo -e "\n\n======================== LOOP $ITERATION ========================\n"
done
