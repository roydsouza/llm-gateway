#!/usr/bin/env bash
# gateway.sh — SwiftLM inference gateway for Apple M5 24GB
# Usage: ./gateway.sh {start|stop|status|info|build}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SWIFTLM_BIN="${SCRIPT_DIR}/swiftlm/.build/release/swiftlm"
CONFIG="${SCRIPT_DIR}/config.json"
PID_FILE="${SCRIPT_DIR}/.swiftlm.pid"
LOG_FILE="${SCRIPT_DIR}/swiftlm.log"

# Defaults (overridden by config.json if present)
PORT=8000
MODEL_PATH="/Users/rds/.cache/huggingface/hub/models--mlx-community--Qwen3.5-35B-A3B-4bit/snapshots/1e20fd8d42056f870933bf98ca6211024744f7ec"

# Read config.json if present
if [[ -f "$CONFIG" ]]; then
    PORT=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('port', 8000))" 2>/dev/null || echo 8000)
    MODEL_PATH=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('model', ''))" 2>/dev/null || echo "$MODEL_PATH")
fi

# ─── SwiftLM Launch Flags ───────────────────────────────────────────
# These are tuned for Gemma 4 MoE (26B, 128 experts, top-k 8) on M5 24GB.
# See TASKS.md for the parameter tuning investigation task.
SWIFTLM_FLAGS=(
    --model "$MODEL_PATH"
    --port "$PORT"
    --thinking                # Enable native reasoning mode (Qwen 3.5 specific)
    --stream-experts          # Memory-map expert weights to NVMe (essential for MoE)
    --ssd-prefetch            # 16-worker background SSD prefetch queue
    --turbo-kv                # KV cache compression (~3.5 bits/token for long contexts)
    --prefill-size 256        # Chunk size for prompt evaluation (lowered to avoid broadcast error)
    --ctx-size 8192           # Explicit context window cap (gates TurboQuant activation)
    --repeat-penalty 1.15     # Server-side repetition penalty (combats Gemma 4 loops)
    --top-k 40                # Tighter sampling for agentic/tool-call reliability
    --min-p 0.05              # Prune low-probability tail tokens
    --temp 0.6                # Default sampling temperature
    --parallel 1              # Single request slot (no concurrent inference)
)

die() { echo "❌ $1" >&2; exit 1; }
info() { echo "ℹ️  $1"; }
ok() { echo "✅ $1"; }

cmd_start() {
    [[ -f "$SWIFTLM_BIN" ]] || die "SwiftLM binary not found at $SWIFTLM_BIN. Run './gateway.sh build' first."

    # Check if already running
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        die "SwiftLM already running (PID $(cat "$PID_FILE")). Stop it first."
    fi

    info "Starting SwiftLM on port $PORT..."
    info "Model: $(basename "$MODEL_PATH")"

    # Set METAL_LIBRARY_PATH and CD into the binary directory to ensure Metal kernels load correctly
    export METAL_LIBRARY_PATH="${SCRIPT_DIR}/swiftlm/.build/release"
    cd "${METAL_LIBRARY_PATH}"
    nohup ./swiftlm "${SWIFTLM_FLAGS[@]}" > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"

    # Wait for health check
    info "Waiting for server health..."
    local retries=0
    while [[ $retries -lt 60 ]]; do
        if curl -sf "http://127.0.0.1:${PORT}/v1/models" > /dev/null 2>&1; then
            ok "SwiftLM running on port $PORT (PID $pid)"
            return 0
        fi
        sleep 2
        retries=$((retries + 1))
    done

    die "SwiftLM failed to start within 120s. Check $LOG_FILE"
}

cmd_stop() {
    if [[ ! -f "$PID_FILE" ]]; then
        info "No PID file found. SwiftLM may not be running."
        # Try to find by port anyway
        local pid
        pid=$(lsof -ti :"$PORT" 2>/dev/null || true)
        if [[ -n "$pid" ]]; then
            info "Found process on port $PORT (PID $pid). Killing..."
            kill "$pid" 2>/dev/null || true
            ok "Process killed."
        else
            info "Nothing running on port $PORT."
        fi
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        info "Stopping SwiftLM (PID $pid)..."
        kill "$pid"
        # Wait for clean exit
        local retries=0
        while kill -0 "$pid" 2>/dev/null && [[ $retries -lt 10 ]]; do
            sleep 1
            retries=$((retries + 1))
        done
        if kill -0 "$pid" 2>/dev/null; then
            info "Force killing..."
            kill -9 "$pid" 2>/dev/null || true
        fi
        ok "SwiftLM stopped."
    else
        info "PID $pid is not running."
    fi
    rm -f "$PID_FILE"
}

cmd_status() {
    echo "━━━ SwiftLM Gateway Status ━━━"
    echo "Binary:  $SWIFTLM_BIN"
    echo "Port:    $PORT"

    # Show human-readable model name from config
    local model_name
    model_name=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('model_name', 'unknown'))" 2>/dev/null || basename "$MODEL_PATH")
    echo "Model:   $model_name"

    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Status:  🟢 RUNNING (PID $(cat "$PID_FILE"))"
    else
        echo "Status:  🔴 STOPPED"
        rm -f "$PID_FILE"
    fi

    # Show model disk size (follow symlinks, use parent HF cache dir for accurate size)
    local model_size
    model_size=$(du -shL "$MODEL_PATH" 2>/dev/null | cut -f1 || echo "unknown")
    echo "Disk:    $model_size"
}

cmd_info() {
    [[ -f "$SWIFTLM_BIN" ]] || die "SwiftLM binary not found. Run './gateway.sh build' first."
    info "Profiling VRAM requirements (dry-run)..."
    local metallib_path="${SCRIPT_DIR}/swiftlm/.build/arm64-apple-macosx/release"
    env METAL_LIBRARY_PATH="$metallib_path" "$SWIFTLM_BIN" --model "$MODEL_PATH" --info
}

cmd_build() {
    info "Building SwiftLM from source..."
    cd "${SCRIPT_DIR}/swiftlm"
    if [[ -f "build.sh" ]]; then
        bash build.sh
    else
        swift build -c release
    fi
    ok "SwiftLM built. Binary at: ${SWIFTLM_BIN}"
}

# ─── Main ───────────────────────────────────────────────────────────
case "${1:-help}" in
    start)  cmd_start ;;
    stop)   cmd_stop ;;
    status) cmd_status ;;
    info)   cmd_info ;;
    build)  cmd_build ;;
    *)
        echo "Usage: ./gateway.sh {start|stop|status|info|build}"
        echo ""
        echo "Commands:"
        echo "  start   Launch SwiftLM with tuned MoE parameters"
        echo "  stop    Gracefully stop SwiftLM"
        echo "  status  Show running state, model, port"
        echo "  info    Profile VRAM requirements (dry-run)"
        echo "  build   Build SwiftLM from source"
        ;;
esac
