#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: run_list_sort_bench.sh [options] [<commit>...]

Builds build/list_sort_bench against each requested Linux commit,
runs the benchmark once per commit, and stores the CSV output.

Options:
  -n, --size <N>        Number of list nodes (default: 100000)
  -p, --param <M>       Parameter passed to sawtooth/staggered patterns (default: 0)
  -o, --output-dir <D>  Directory to store CSV files (default: ./bench_results)
      --skip-clean      Skip "make clean" between commits
  -h, --help            Show this help

Example:
  ./run_list_sort_bench.sh -n 200000 b5c56e0 b5c56e0^

Notes:
  - Without explicit commits, defaults to commit b5c56e0 (its parent runs automatically).
  - For each commit provided, the script also benchmarks its immediate parent (<commit>^).
EOF
}

PERF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$PERF_DIR/.." && pwd)"
LINUX_DIR="$REPO_ROOT/third_party/linux"
BENCH_BIN="$REPO_ROOT/build/list_sort_bench"
OUT_DIR="$REPO_ROOT/bench_results"
RUN_CLEAN=1
SIZE=100000
PATTERN_PARAM=0
COMMITS=()
DEFAULT_COMMITS=("b5c56e0")

while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--size)
        [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
        SIZE="$2"
        shift 2
        ;;
    -p|--param)
        [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
        PATTERN_PARAM="$2"
        shift 2
        ;;
    -o|--output-dir)
        [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
        OUT_DIR="$2"
        shift 2
        ;;
    --skip-clean)
        RUN_CLEAN=0
        shift
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    --)
        shift
        while [[ $# -gt 0 ]]; do
            COMMITS+=("$1")
            shift
        done
        ;;
    -*)
        echo "Unknown option: $1" >&2
        usage
        exit 2
        ;;
    *)
        COMMITS+=("$1")
        shift
        ;;
    esac
done

if [[ ${#COMMITS[@]} -eq 0 ]]; then
    echo "No commits specified; defaulting to ${DEFAULT_COMMITS[*]}"
    COMMITS=("${DEFAULT_COMMITS[@]}")
fi

should_add_parent() {
    local spec="$1"
    [[ "$spec" != *"^"* && "$spec" != *"~"* ]]
}

EXPANDED_COMMITS=()
for commit in "${COMMITS[@]}"; do
    EXPANDED_COMMITS+=("$commit")
    if should_add_parent "$commit"; then
        EXPANDED_COMMITS+=("${commit}^")
    fi
done
COMMITS=("${EXPANDED_COMMITS[@]}")

if [[ ! -d "$LINUX_DIR/.git" && ! -f "$LINUX_DIR/.git" ]]; then
    echo "Expected Linux source at $LINUX_DIR (git repo not found)." >&2
    exit 1
fi

if [[ -n "$(git -C "$LINUX_DIR" status --porcelain)" ]]; then
    echo "Linux tree has local changes; commit/stash them before running this script." >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

ORIG_COMMIT="$(git -C "$LINUX_DIR" rev-parse HEAD)"
cleanup() {
    git -C "$LINUX_DIR" checkout -q "$ORIG_COMMIT"
}
trap cleanup EXIT

build_bench() {
    if [[ $RUN_CLEAN -eq 1 ]]; then
        make -C "$REPO_ROOT" clean-build
    fi
    make -C "$REPO_ROOT" -j"$(nproc)"
}

run_once() {
    local commit="$1"
    local resolved
    local resolved_short
    resolved="$(git -C "$LINUX_DIR" rev-parse "$commit")"
    resolved_short="$(git -C "$LINUX_DIR" rev-parse --short "$resolved")"
    echo "==> Switching Linux tree to $commit ($resolved)"
    git -C "$LINUX_DIR" checkout -q "$resolved"
    build_bench

    mkdir -p "$OUT_DIR"
    local outfile="$OUT_DIR/list_sort_${resolved_short}.csv"
    {
        printf "# commit=%s\n" "$commit"
        printf "# resolved=%s\n" "$resolved"
        printf "# size=%s\n" "$SIZE"
        printf "# param=%s\n" "$PATTERN_PARAM"
    } >"$outfile"
    echo "    Running $BENCH_BIN -> $outfile"
    "$BENCH_BIN" "$SIZE" "$PATTERN_PARAM" | tee -a "$outfile"
}

for commit in "${COMMITS[@]}"; do
    run_once "$commit"
done
