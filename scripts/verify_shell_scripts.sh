#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: verify_shell_scripts.sh [options]

Lint all repository shell scripts with shellcheck.

Options:
  --memorykernel-root <path> Path to MemoryKernel repo root (default: script/..)
  -h, --help                 Show this help
USAGE
}

resolve_path() {
  local path="$1"
  if [[ -d "$path" ]]; then
    (cd "$path" && pwd -P)
  else
    printf "%s\n" "$path"
  fi
}

memorykernel_root=""

while (($# > 0)); do
  case "$1" in
    --memorykernel-root)
      memorykernel_root="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
if [[ -z "$memorykernel_root" ]]; then
  memorykernel_root=$(resolve_path "$script_dir/..")
else
  memorykernel_root=$(resolve_path "$memorykernel_root")
fi

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck is required but not installed." >&2
  echo "Install it and re-run this script." >&2
  exit 1
fi

mapfile -d '' shell_scripts < <(find "$memorykernel_root/scripts" -type f -name '*.sh' -print0 | sort -z)
if [[ ${#shell_scripts[@]} -eq 0 ]]; then
  echo "no shell scripts found under $memorykernel_root/scripts" >&2
  exit 1
fi

shellcheck --external-sources --severity=info "${shell_scripts[@]}"
echo "Shell script lint checks passed."
