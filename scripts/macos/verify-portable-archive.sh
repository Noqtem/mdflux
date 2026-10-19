#!/usr/bin/env bash
# Validate a macOS MDFlux archive after extraction. Run this on macOS.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

[[ "$#" == 3 ]] || die "Usage: $0 ARCHIVE macos-arm64|macos-x64 lite|full"
archive="$1"
expected_platform="$2"
expected_edition="$3"

[[ -f "$archive" ]] || die "Archive not found: $archive"
[[ "$(uname -s)" == Darwin ]] || die "Archive verification must run on macOS"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/mdflux-verify.XXXXXX")"
cleanup() { [[ "$tmp" == "${TMPDIR:-/tmp}"/mdflux-verify.* ]] && rm -rf -- "$tmp"; }
trap cleanup EXIT

tar -xzf "$archive" -C "$tmp"

[[ -x "$tmp/MDFlux" ]] || die "MDFlux is missing or not executable"
[[ -d "$tmp/resources/sidecar" ]] || die "Sidecar directory is missing"
manifest="$tmp/resources/edition.json"
[[ -f "$manifest" ]] || die "edition.json is missing"

python3 - "$manifest" "$expected_platform" "$expected_edition" <<'PY'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
required = {"schema", "edition", "app_version", "commit", "platform", "python_version", "components", "dependency_lock_sha256", "built_at_utc"}
assert not required - m.keys(), f"manifest fields missing: {sorted(required - m.keys())}"
assert m["schema"] == 1 and m["platform"] == sys.argv[2] and m["edition"] == sys.argv[3]
assert m["components"] == (["core"] if sys.argv[3] == "lite" else ["core", "ocr", "audio-runtime"])
assert (m["python_version"] is None) if sys.argv[3] == "lite" else isinstance(m["python_version"], str)
PY

lock="$tmp/resources/sidecar/requirements-full.lock"
[[ -f "$lock" ]] || die "Packaged requirements-full.lock is missing"

expected_hash="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["dependency_lock_sha256"])' "$manifest")"
actual_hash="$(shasum -a 256 "$lock" | awk '{print $1}')"
[[ "$actual_hash" == "$expected_hash" ]] || die "Dependency lock checksum mismatch"

if [[ "$expected_edition" == lite ]]; then
  [[ ! -e "$tmp/resources/runtime" ]] || die "Lite archive unexpectedly bundles a runtime"
else
  runtime_root="$tmp/resources/runtime"
  runtime="$runtime_root/bin/python3"
  [[ -x "$runtime" ]] || die "Full archive is missing executable resources/runtime/bin/python3"
  "$runtime" -I -c 'import markitdown, openai, httpx, rapidocr, onnxruntime, pypdfium2, faster_whisper, ctranslate2'
  printf '%s\n' '{"v":1,"id":"packaging-health","method":"health","params":{}}' | (cd "$tmp/resources/sidecar" && "$runtime" main.py) | grep -q '"ok": true' || die "Packaged sidecar health request failed"
fi

if grep -RIl --exclude='*.pyc' --exclude='*.dylib' --exclude='*.so' -E '_mdflux_macos_(lite|full)_stage' "$tmp"; then
  die "Archive contains a staging path leak"
fi

echo "Verified $archive ($expected_platform, $expected_edition)"
