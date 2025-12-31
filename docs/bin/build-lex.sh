#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$DOCS_DIR/_lex_src"
OUT_DIR="$DOCS_DIR/_includes/lex"
CSS_PATH="${LEX_CSS_PATH:-$DOCS_DIR/assets/css/lex-content.css}"
LEX_BIN="${LEX_BIN:-lex}"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "No Lex sources in $SRC_DIR" >&2
  exit 1
fi

if [[ ! -f "$CSS_PATH" ]]; then
  echo "Missing CSS file at $CSS_PATH" >&2
  exit 1
fi

if command -v "$LEX_BIN" >/dev/null 2>&1; then
  true
elif [[ -x "$LEX_BIN" ]]; then
  true
else
  echo "Could not find lex binary '$LEX_BIN'. Set LEX_BIN to the binary path." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
tmp_html="$(mktemp -t lex-page.XXXXXX)"
cleanup() {
  rm -f "$tmp_html"
}
trap cleanup EXIT

shopt -s nullglob
found=0
while IFS= read -r -d '' src; do
  found=1
  rel="${src#$SRC_DIR/}"
  base="${rel%.lex}"
  dest="$OUT_DIR/${base}.html"
  mkdir -p "$(dirname "$dest")"
  echo "[lex] $rel -> ${dest#$DOCS_DIR/}"
  "$LEX_BIN" "$src" --to html --extras-css-path "$CSS_PATH" > "$tmp_html"
  python3 - "$tmp_html" "$dest" <<'PY'
import pathlib, sys
html_path, dest_path = sys.argv[1], sys.argv[2]
html = pathlib.Path(html_path).read_text()
start_marker = '<div class="lex-document">'
start = html.find(start_marker)
if start == -1:
    raise SystemExit('lex output is missing the lex-document wrapper')
end = html.find('</body>')
if end == -1:
    raise SystemExit('lex output is missing </body> marker')
fragment = html[start:end].rstrip() + '\n'
pathlib.Path(dest_path).write_text(fragment)
PY
done < <(find "$SRC_DIR" -name '*.lex' -print0 | sort -z)

if [[ $found -eq 0 ]]; then
  echo "No .lex files found under $SRC_DIR" >&2
fi
