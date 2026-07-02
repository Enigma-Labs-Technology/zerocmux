#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/Resources/bin/start-zerocmux-profiling"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

make_app() {
  local path="$1"
  local bundle_id="$2"
  local display_name="$3"
  mkdir -p "$path/Contents/MacOS"
  cat > "$path/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>$bundle_id</string>
  <key>CFBundleDisplayName</key>
  <string>$display_name</string>
</dict>
</plist>
EOF
  : > "$path/Contents/MacOS/zerocmux"
}

stable_app="$TMP_DIR/zerocmux.app"
nightly_app="$TMP_DIR/zerocmux NIGHTLY.app"
dev_app="$TMP_DIR/zerocmux DEV dog.app"
make_app "$stable_app" "com.kernelalex.zerocmux" "zerocmux"
make_app "$nightly_app" "com.kernelalex.zerocmux.nightly" "zerocmux NIGHTLY"
make_app "$dev_app" "com.kernelalex.zerocmux.debug.dog" "zerocmux DEV dog"

plist_buddy="$TMP_DIR/plistbuddy"
cat > "$plist_buddy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

command="${2:-}"
plist="${3:-}"
key="${command#Print :}"
python3 - "$key" "$plist" <<'PY'
import plistlib
import sys

key = sys.argv[1]
path = sys.argv[2]
with open(path, "rb") as handle:
    value = plistlib.load(handle).get(key, "")
if value:
    print(value)
PY
EOF
chmod +x "$plist_buddy"
export CMUX_PROFILE_PLIST_BUDDY="$plist_buddy"

defaults_bin="$TMP_DIR/defaults"
cat > "$defaults_bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "read" ] && [ "${2:-}" = "com.apple.HIToolbox" ] && [ "${3:-}" = "AppleSelectedInputSources" ]; then
  cat <<'PLIST'
(
    {
        "InputSourceKind" = "Keyboard Layout";
        "KeyboardLayout ID" = 0;
        "KeyboardLayout Name" = "U.S.";
    }
)
PLIST
  exit 0
fi
exit 1
EOF
chmod +x "$defaults_bin"
export CMUX_PROFILE_DEFAULTS="$defaults_bin"

system_profiler_bin="$TMP_DIR/system_profiler"
cat > "$system_profiler_bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'PROFILE'
Graphics/Displays:

    Apple M3 Max:

      Chipset Model: Apple M3 Max
      Metal Support: Metal 3

        Color LCD:

          Resolution: 3456 x 2234 Retina
          Main Display: Yes
          Online: Yes
PROFILE
EOF
chmod +x "$system_profiler_bin"
export CMUX_PROFILE_SYSTEM_PROFILER="$system_profiler_bin"

ps_file="$TMP_DIR/ps.txt"
cat > "$ps_file" <<EOF
101 $stable_app/Contents/MacOS/zerocmux
202 $nightly_app/Contents/MacOS/zerocmux
303 $dev_app/Contents/MacOS/zerocmux
EOF

dry_run="$("$SCRIPT" --dry-run --test-ps-file "$ps_file" --channel dev --tag dog --duration 7 --out "$TMP_DIR/out")"
if [[ "$dry_run" != *"Target: pid=303 channel=dev bundle=com.kernelalex.zerocmux.debug.dog name=zerocmux DEV dog"* ]]; then
  echo "FAIL: dev tag selector did not choose the tagged dev process" >&2
  echo "$dry_run" >&2
  exit 1
fi
if [[ "$dry_run" != *'--template "Time Profiler" --attach "303" --time-limit 7s'* ]]; then
  echo "FAIL: dry run did not include Time Profiler for the selected process" >&2
  echo "$dry_run" >&2
  exit 1
fi
if [[ "$dry_run" != *'--template "SwiftUI" --attach "303" --time-limit 7s'* ]]; then
  echo "FAIL: dry run did not include SwiftUI for the selected process" >&2
  echo "$dry_run" >&2
  exit 1
fi
if [[ "$dry_run" != *'--template "Allocations" --attach "303" --time-limit 7s'* ]]; then
  echo "FAIL: dry run did not include Allocations for the selected process" >&2
  echo "$dry_run" >&2
  exit 1
fi
if [[ "$dry_run" != *'--template "System Trace" --attach "303" --time-limit 7s'* ]]; then
  echo "FAIL: dry run did not include System Trace for the selected process" >&2
  echo "$dry_run" >&2
  exit 1
fi
if [ -e "$TMP_DIR/out" ]; then
  echo "FAIL: dry run created the output directory" >&2
  find "$TMP_DIR/out" -maxdepth 2 -type f -print >&2
  exit 1
fi

if "$SCRIPT" --dry-run --test-ps-file "$ps_file" --out "$TMP_DIR/ambiguous" >/tmp/zerocmux-profile-ambiguous.log 2>&1; then
  echo "FAIL: unqualified selection should reject multiple zerocmux processes" >&2
  exit 1
fi
if ! grep -Fq "multiple zerocmux processes are running" /tmp/zerocmux-profile-ambiguous.log; then
  echo "FAIL: ambiguous selection did not explain how to discriminate instances" >&2
  cat /tmp/zerocmux-profile-ambiguous.log >&2
  exit 1
fi

list_output="$("$SCRIPT" --list-targets --test-ps-file "$ps_file")"
if [[ "$list_output" != *"pid=101 channel=stable bundle=com.kernelalex.zerocmux"* ]] ||
   [[ "$list_output" != *"pid=202 channel=nightly bundle=com.kernelalex.zerocmux.nightly"* ]] ||
   [[ "$list_output" != *"pid=303 channel=dev bundle=com.kernelalex.zerocmux.debug.dog"* ]]; then
  echo "FAIL: --list-targets did not show stable/nightly/dev discrimination" >&2
  echo "$list_output" >&2
  exit 1
fi

fake_bin="$TMP_DIR/fake-bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/xcrun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "-f" ]; then
  echo "$0"
  exit 0
fi

if [ "${1:-}" = "xctrace" ] && [ "${2:-}" = "record" ]; then
  output=""
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--output" ]; then
      output="$2"
      break
    fi
    shift
  done
  mkdir -p "$output"
  exit 0
fi

if [ "${1:-}" = "xctrace" ] && [ "${2:-}" = "export" ]; then
  sleep 5
  exit 0
fi

exit 1
EOF
chmod +x "$fake_bin/xcrun"

timeout_out="$TMP_DIR/timeout-out"
HOME="$TMP_DIR" PATH="$fake_bin:$PATH" CMUX_PROFILE_TOC_TIMEOUT_SECONDS=1 "$SCRIPT" \
  --test-ps-file "$ps_file" \
  --channel dev \
  --tag dog \
  --duration 1 \
  --template "Time Profiler" \
  --no-submit \
  --out "$timeout_out" >/dev/null
if ! grep -Fq "Timed out after 1s" "$timeout_out/time-profiler-toc.log"; then
  echo "FAIL: hung TOC export did not time out" >&2
  cat "$timeout_out/time-profiler-toc.log" >&2
  exit 1
fi
if ! grep -Fq "Completed:" "$timeout_out/summary.md"; then
  echo "FAIL: script did not complete after TOC export timeout" >&2
  cat "$timeout_out/summary.md" >&2
  exit 1
fi
if ! grep -Fq "Successful traces: 1" "$timeout_out/summary.md"; then
  echo "FAIL: script did not count the successful trace" >&2
  cat "$timeout_out/summary.md" >&2
  exit 1
fi
if [ ! -f "$timeout_out/system-info.txt" ] ||
   ! grep -Fq "KeyboardLayout Name" "$timeout_out/system-info.txt" ||
   ! grep -Fq "Apple M3 Max" "$timeout_out/system-info.txt" ||
   ! grep -Fq "Excludes serial numbers" "$timeout_out/system-info.txt"; then
  echo "FAIL: script did not write non-sensitive system info" >&2
  cat "$timeout_out/system-info.txt" >&2
  exit 1
fi
if ! grep -Fq "System:" "$timeout_out/summary.md" ||
   ! grep -Fq "App: ~/zerocmux DEV dog.app" "$timeout_out/summary.md" ||
   ! grep -Fq "Keyboard/input source: U.S." "$timeout_out/summary.md" ||
   ! grep -Fq "More details: system-info.txt" "$timeout_out/summary.md"; then
  echo "FAIL: summary did not preview system info" >&2
  cat "$timeout_out/summary.md" >&2
  exit 1
fi
if grep -Fq "$TMP_DIR/zerocmux DEV dog.app" "$timeout_out/summary.md" ||
   grep -Fq "$TMP_DIR/zerocmux DEV dog.app" "$timeout_out/system-info.txt"; then
  echo "FAIL: system info leaked an unredacted home path" >&2
  cat "$timeout_out/summary.md" >&2
  cat "$timeout_out/system-info.txt" >&2
  exit 1
fi

failing_system_profiler="$TMP_DIR/failing-system-profiler"
cat > "$failing_system_profiler" <<'EOF'
#!/usr/bin/env bash
exit 9
EOF
chmod +x "$failing_system_profiler"
display_failed_out="$TMP_DIR/display-failed-out"
PATH="$fake_bin:$PATH" CMUX_PROFILE_SYSTEM_PROFILER="$failing_system_profiler" "$SCRIPT" \
  --test-ps-file "$ps_file" \
  --channel dev \
  --tag dog \
  --duration 1 \
  --template "Time Profiler" \
  --no-submit \
  --out "$display_failed_out" >/dev/null
if ! grep -Fq "Completed:" "$display_failed_out/summary.md" ||
   ! grep -Fq "Displays: unknown" "$display_failed_out/summary.md"; then
  echo "FAIL: optional display probing failure should not abort profiling" >&2
  cat "$display_failed_out/summary.md" >&2
  exit 1
fi

sleep_system_profiler="$TMP_DIR/sleep-system-profiler"
cat > "$sleep_system_profiler" <<'EOF'
#!/usr/bin/env bash
sleep 30
EOF
chmod +x "$sleep_system_profiler"
display_hung_out="$TMP_DIR/display-hung-out"
PATH="$fake_bin:$PATH" CMUX_PROFILE_SYSTEM_PROFILER="$sleep_system_profiler" CMUX_PROFILE_SYSTEM_PROFILER_TIMEOUT_SECONDS=1 "$SCRIPT" \
  --test-ps-file "$ps_file" \
  --channel dev \
  --tag dog \
  --duration 1 \
  --template "Time Profiler" \
  --no-submit \
  --out "$display_hung_out" >/dev/null
if ! grep -Fq "Completed:" "$display_hung_out/summary.md" ||
   ! grep -Fq "Displays: unknown" "$display_hung_out/summary.md"; then
  echo "FAIL: hung optional display probe should time out and not abort profiling" >&2
  cat "$display_hung_out/summary.md" >&2
  exit 1
fi

fail_bin="$TMP_DIR/fail-bin"
mkdir -p "$fail_bin"
cat > "$fail_bin/xcrun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "-f" ]; then
  echo "$0"
  exit 0
fi

if [ "${1:-}" = "xctrace" ] && [ "${2:-}" = "record" ]; then
  echo "record failed" >&2
  exit 2
fi

exit 1
EOF
chmod +x "$fail_bin/xcrun"

all_failed_out="$TMP_DIR/all-failed-out"
if PATH="$fail_bin:$PATH" "$SCRIPT" \
  --test-ps-file "$ps_file" \
  --channel dev \
  --tag dog \
  --duration 1 \
  --template "Time Profiler" \
  --no-submit \
  --out "$all_failed_out" >/tmp/zerocmux-profile-all-failed.log 2>&1; then
  echo "FAIL: all-failed profiling run should exit nonzero" >&2
  exit 1
fi
if ! grep -Fq "all profiling templates failed" /tmp/zerocmux-profile-all-failed.log ||
   ! grep -Fq "Successful traces: 0" "$all_failed_out/summary.md" ||
   grep -Fq "Completed:" "$all_failed_out/summary.md"; then
  echo "FAIL: all-failed profiling run did not surface failure correctly" >&2
  cat /tmp/zerocmux-profile-all-failed.log >&2
  cat "$all_failed_out/summary.md" >&2
  exit 1
fi

# zerocmux: the profiling email submitter was removed with the hosted feedback
# surface; captures stay local. No submit helper to exercise.

echo "PASS: start-zerocmux-profiling target selection and default templates"
