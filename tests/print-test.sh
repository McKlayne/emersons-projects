#!/usr/bin/env bash
#
# Verifies that the "Print Infographic" action produces exactly ONE page.
#
# Prints research-process-infographic.html to PDF with headless Chrome
# (US Letter landscape, as declared in the page's @page rule) and asserts
# a page count of 1. Also checks an A4 landscape variant.
#
# Requirements: google-chrome (or chromium) and python3. No extra packages.
#
# Usage: tests/print-test.sh [output-dir]   (default: ./test-output)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/test-output}"
HTML="$REPO_ROOT/research-process-infographic.html"
mkdir -p "$OUT_DIR"

CHROME="$(command -v google-chrome || command -v chromium || command -v chromium-browser)"
CHROME_FLAGS=(--headless --disable-gpu --no-sandbox --disable-dev-shm-usage
              --virtual-time-budget=5000 --no-pdf-header-footer)

print_pdf() { # $1 = html path, $2 = pdf path
    # timeout guards against Chrome hanging on exit after the PDF is written
    timeout 60 "$CHROME" "${CHROME_FLAGS[@]}" --print-to-pdf="$2" "file://$1" 2>/dev/null || true
    [ -s "$2" ] || { echo "FAIL: $2 was not generated"; exit 1; }
}

page_count() { # $1 = pdf path
    python3 - "$1" <<'EOF'
import re, sys
data = open(sys.argv[1], 'rb').read()
counts = re.findall(rb'/Type\s*/Pages[^>]*?/Count\s+(\d+)', data, re.S)
print(max(int(c) for c in counts) if counts
      else len(re.findall(rb'/Type\s*/Page[^s]', data)))
EOF
}

fail=0

# --- US Letter (the page's own @page rule) ---
print_pdf "$HTML" "$OUT_DIR/infographic-letter.pdf"
letter_pages="$(page_count "$OUT_DIR/infographic-letter.pdf")"
echo "US Letter landscape: $letter_pages page(s)"
[ "$letter_pages" = "1" ] || { echo "FAIL: expected 1 page on US Letter"; fail=1; }

# --- A4 variant (swap the @page size, everything else identical) ---
sed 's/size: letter landscape;/size: A4 landscape;/' "$HTML" > "$OUT_DIR/a4-variant.html"
print_pdf "$OUT_DIR/a4-variant.html" "$OUT_DIR/infographic-a4.pdf"
a4_pages="$(page_count "$OUT_DIR/infographic-a4.pdf")"
echo "A4 landscape:        $a4_pages page(s)"
[ "$a4_pages" = "1" ] || { echo "FAIL: expected 1 page on A4"; fail=1; }

if [ "$fail" = "0" ]; then
    echo "PASS: infographic prints on exactly one page (Letter and A4)"
else
    exit 1
fi
