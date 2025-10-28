#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 s3://bucket-name [--profile PROFILE] [--region REGION]

Prints human-readable totals for each top-level "folder" (prefix) in an S3 bucket,
similar to: du -sh *

Examples:
  $0 s3://my-bucket
  $0 s3://my-bucket --profile prod --region us-east-1
EOF
}

hr_bytes() {
  # Human-readable bytes with 1 decimal (no numfmt dependency required)
  local b="$1"
  awk -v b="$b" '
    BEGIN {
      n = split("B KiB MiB GiB TiB PiB EiB", u, " ");
      val = b + 0.0;
      i = 1;
      while (val >= 1024 && i < n) { val /= 1024; i++ }
      printf("%.1f %s", val, u[i]);
    }'
}

# --- Parse args ---
[[ $# -lt 1 ]] && usage && exit 1
BUCKET=""
PROFILE=()
REGION=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    s3://*) BUCKET="${1#s3://}"; shift;;
    --bucket) BUCKET="$2"; shift 2;;
    --profile) PROFILE=(--profile "$2"); shift 2;;
    --region)  REGION=(--region "$2");  shift 2;;
    -h|--help) usage; exit 0;;
    *) if [[ -z "$BUCKET" ]]; then BUCKET="$1"; shift; else echo "Unknown arg: $1"; usage; exit 1; fi;;
  esac
done

[[ -z "$BUCKET" ]] && { echo "Bucket is required"; usage; exit 1; }

command -v aws >/dev/null 2>&1 || { echo "aws CLI not found"; exit 1; }

# We stream with `aws s3 ls --recursive` to avoid N calls per prefix.
# Format per line: YYYY-MM-DD HH:MM:SS <size> <key...>
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

aws s3 ls "s3://$BUCKET" --recursive "${PROFILE[@]}" "${REGION[@]}" \
| awk '
  NF>=4 {
    # size is field 3
    size = $3 + 0
    # key is the remainder of the line after first 3 fields (handles spaces in keys)
    key = $0
    sub(/^[0-9-]+[[:space:]]+[0-9:]+[[:space:]]+[0-9]+[[:space:]]+/, "", key)
    # determine top-level root
    idx = index(key, "/")
    if (idx > 0) {
      root = substr(key, 1, idx-1)
    } else {
      root = "[root]"
    }
    bytes[root] += size
  }
  END {
    for (k in bytes) {
      printf "%s\t%s\n", bytes[k], k
    }
  }' > "$TMP"

# Sort by size desc and print human-readable
TOTAL=0
while IFS=$'\t' read -r BYTES NAME; do
  TOTAL=$((TOTAL + BYTES))
done < <(cat "$TMP")

while IFS=$'\t' read -r BYTES NAME; do
  printf "%8s  %s\n" "$(hr_bytes "$BYTES")" "$NAME"
done < <(sort -nr -k1,1 "$TMP")

echo "--------"
printf "%8s  %s\n" "$(hr_bytes "$TOTAL")" "TOTAL"