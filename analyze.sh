#!/bin/bash
# CTF Binary Analyzer — strace + ltrace in isolated Docker container
# Usage: ./analyze.sh <binary> [args to pass to binary]

set -e

# ── Args ────────────────────────────────────────────────────────────────────
if [ $# -eq 0 ]; then
    echo "Usage: $0 <binary> [binary args...]"
    echo "  Example: $0 ./challenge"
    echo "  Example: $0 ./challenge secretinput"
    exit 1
fi

BINARY="$1"
shift
BINARY_ARGS="$@"

if [ ! -f "$BINARY" ]; then
    echo "[!] File not found: $BINARY"
    exit 1
fi

BINARY_NAME=$(basename "$BINARY")
IMAGE_NAME="ctf-analyzer"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$(pwd)/analysis_${BINARY_NAME}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

# ── Build image if needed ───────────────────────────────────────────────────
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "[+] Building analysis image (first run only)..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR" -q
    echo "[+] Image built."
fi

# ── Create container ────────────────────────────────────────────────────────
echo "[+] Starting isolated container..."
CONTAINER=$(docker create \
    --network none \
    --cap-drop ALL \
    --cap-add SYS_PTRACE \
    --security-opt no-new-privileges \
    --memory 256m \
    --pids-limit 64 \
    -v "$(realpath "$OUTPUT_DIR")":/output \
    "$IMAGE_NAME" \
    sleep 120)

# Copy binary into container and start it
docker cp "$(realpath "$BINARY")" "$CONTAINER":/analysis/"$BINARY_NAME"
docker start "$CONTAINER" > /dev/null

# ── strace ──────────────────────────────────────────────────────────────────
echo "[+] Running strace..."
docker exec "$CONTAINER" \
    strace \
        -f \
        -tt \
        -s 256 \
        -o /output/strace.txt \
        /analysis/"$BINARY_NAME" $BINARY_ARGS 2>/dev/null || true

echo "[+] strace done → $OUTPUT_DIR/strace.txt"

# ── ltrace ──────────────────────────────────────────────────────────────────
echo "[+] Running ltrace..."
docker exec "$CONTAINER" \
    ltrace \
        -f \
        -i \
        -C \
        -s 256 \
        -o /output/ltrace.txt \
        /analysis/"$BINARY_NAME" $BINARY_ARGS 2>/dev/null || true

echo "[+] ltrace done → $OUTPUT_DIR/ltrace.txt"

# ── Destroy container ────────────────────────────────────────────────────────
docker rm -f "$CONTAINER" > /dev/null
echo "[+] Container destroyed."

# ── Highlights ───────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
echo "  HIGHLIGHTS"
echo "══════════════════════════════════════════════"

echo ""
echo "── Program output (strace write calls) ───────"
grep 'write(1,' "$OUTPUT_DIR/strace.txt" 2>/dev/null \
    | grep -o '"[^"]*"' | tr -d '"' || echo "  (none)"

echo ""
echo "── Files opened ───────────────────────────────"
grep -E 'openat?\(' "$OUTPUT_DIR/strace.txt" 2>/dev/null \
    | grep -v ' = -1' | grep -o '"[^"]*"' | tr -d '"' \
    | grep -v '^/$\|^/proc\|^/dev\|^/etc/ld' || echo "  (none)"

echo ""
echo "── String comparisons (flag checks!) ─────────"
grep -E 'strcmp|strncmp|memcmp|strcasecmp|strstr' "$OUTPUT_DIR/ltrace.txt" 2>/dev/null \
    || echo "  (none)"

echo ""
echo "── Exec calls ────────────────────────────────"
grep 'execve(' "$OUTPUT_DIR/strace.txt" 2>/dev/null || echo "  (none)"

echo ""
echo "══════════════════════════════════════════════"
echo "  Full output: $OUTPUT_DIR/"
echo "    strace.txt — all syscalls"
echo "    ltrace.txt — all library calls"
echo "══════════════════════════════════════════════"
