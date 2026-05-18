#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/build-ghostty-cli-helper.sh [--universal | --target <zig-target>] --output <path>

Options:
  --universal      Build a universal macOS helper (arm64 + x86_64).
  --target <triple>
                   Build a single target, e.g. `aarch64-macos` or `x86_64-macos`.
  --output <path>  Destination path for the built helper.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GHOSTTY_DIR="$REPO_ROOT/ghostty"

OUTPUT_PATH=""
TARGET_TRIPLE=""
UNIVERSAL="false"

zig_binary_arch() {
  local zig_path="$1"
  file "$zig_path" 2>/dev/null | grep -oE '(arm64|x86_64)' | head -1 || true
}

target_arch_for_triple() {
  case "${1:-}" in
    aarch64-macos) echo "arm64" ;;
    x86_64-macos) echo "x86_64" ;;
  esac
}

sdk_supports_zig_arm64() {
  local sdk_path="$1"
  local libsystem="$sdk_path/usr/lib/libSystem.tbd"
  [[ -f "$libsystem" ]] || return 1
  grep -Eq '(^|[^[:alnum:]_])arm64-macos([^[:alnum:]_]|$)' "$libsystem"
}

sdk_is_zig_015_compatible() {
  local sdk_path="$1"
  local real_sdk=""
  real_sdk="$(cd "$sdk_path" 2>/dev/null && pwd -P)" || return 1
  local sdk_version=""
  sdk_version="$(/usr/libexec/PlistBuddy -c 'Print :Version' "$sdk_path/SDKSettings.plist" 2>/dev/null || true)"
  case "$sdk_version" in
    2[6-9]*|[3-9]*) return 1 ;;
  esac
  case "$(basename "$real_sdk")" in
    MacOSX2[6-9]*.sdk) return 1 ;;
  esac
  sdk_supports_zig_arm64 "$sdk_path"
}

select_zig_macos_sdk() {
  local current_sdk=""
  current_sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
  if [[ -n "$current_sdk" && -d "$current_sdk" ]] && sdk_is_zig_015_compatible "$current_sdk"; then
    echo "$current_sdk"
    return 0
  fi

  local sdk=""
  local -a candidates=()
  for sdk in \
    /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk \
    /Applications/Xcode*.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX*.sdk; do
    [[ -d "$sdk" ]] || continue
    candidates+=("$sdk")
  done

  if [[ "${#candidates[@]}" -gt 0 ]]; then
    while IFS= read -r sdk; do
      if sdk_is_zig_015_compatible "$sdk"; then
        echo "$sdk"
        return 0
      fi
    done < <(printf '%s\n' "${candidates[@]}" | sort -r)
  fi

  [[ -n "$current_sdk" ]] && echo "$current_sdk"
}

prepare_zig_xcrun_wrapper() {
  local sdk_path=""
  sdk_path="$(select_zig_macos_sdk || true)"
  [[ -n "$sdk_path" ]] || return 0

  local current_sdk=""
  current_sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
  if [[ "$sdk_path" == "$current_sdk" ]]; then
    return 0
  fi

  ZIG_MACOS_SDKROOT="$sdk_path"
  ZIG_XCRUN_WRAPPER_DIR="$TMP_DIR/xcrun-wrapper"
  mkdir -p "$ZIG_XCRUN_WRAPPER_DIR"
  cat > "$ZIG_XCRUN_WRAPPER_DIR/xcrun" <<'EOF'
#!/bin/sh
case " $* " in
  *" --show-sdk-path "*)
    printf '%s\n' "$ZIG_MACOS_SDKROOT"
    exit 0
    ;;
esac
exec /usr/bin/xcrun "$@"
EOF
  chmod +x "$ZIG_XCRUN_WRAPPER_DIR/xcrun"
  echo "Using macOS SDK $ZIG_MACOS_SDKROOT for Zig"
}

select_zig_for_target() {
  local target="${1:-}"
  local desired_arch
  desired_arch="$(target_arch_for_triple "$target")"

  if [[ -n "${CMUX_ZIG:-}" ]]; then
    if [[ ! -x "$CMUX_ZIG" ]]; then
      echo "error: CMUX_ZIG is not executable: $CMUX_ZIG" >&2
      return 1
    fi
    echo "$CMUX_ZIG"
    return 0
  fi

  local -a candidates=()
  local path_zig=""
  path_zig="$(command -v zig 2>/dev/null || true)"
  [[ -n "$path_zig" ]] && candidates+=("$path_zig")
  candidates+=("/opt/homebrew/bin/zig" "/usr/local/bin/zig")

  local fallback=""
  local seen=" "
  local candidate=""
  local canonical=""
  local arch=""
  for candidate in "${candidates[@]}"; do
    [[ -x "$candidate" ]] || continue
    canonical="$(cd "$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
    [[ "$seen" == *" $canonical "* ]] && continue
    seen="${seen}${canonical} "
    [[ -z "$fallback" ]] && fallback="$canonical"
    if [[ -n "$desired_arch" ]]; then
      arch="$(zig_binary_arch "$canonical")"
      if [[ "$arch" == "$desired_arch" ]]; then
        echo "$canonical"
        return 0
      fi
    fi
  done

  if [[ -n "$fallback" ]]; then
    echo "$fallback"
    return 0
  fi

  echo "error: zig is required to build the Ghostty CLI helper" >&2
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --universal)
      UNIVERSAL="true"
      shift
      ;;
    --target)
      TARGET_TRIPLE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "Missing required --output path" >&2
  usage >&2
  exit 1
fi

# Allow CI to skip the zig build (e.g., macOS 26 where zig 0.15.2 can't link).
# Creates a stub binary so the Xcode Run Script file-existence check passes.
if [[ "${CMUX_SKIP_ZIG_BUILD:-}" == "1" ]]; then
  echo "Skipping zig CLI helper build (CMUX_SKIP_ZIG_BUILD=1)"
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  printf '#!/bin/sh\necho "ghostty CLI helper stub (zig build skipped)" >&2\nexit 1\n' > "$OUTPUT_PATH"
  chmod +x "$OUTPUT_PATH"
  exit 0
fi

if [[ "$UNIVERSAL" == "true" && -n "$TARGET_TRIPLE" ]]; then
  echo "--universal and --target are mutually exclusive" >&2
  usage >&2
  exit 1
fi

if [[ -n "$TARGET_TRIPLE" ]]; then
  case "$TARGET_TRIPLE" in
    aarch64-macos|x86_64-macos)
      ;;
    *)
      echo "Unsupported --target value: $TARGET_TRIPLE" >&2
      exit 1
      ;;
  esac
fi

if [[ ! -f "$GHOSTTY_DIR/build.zig" ]]; then
  echo "error: Ghostty submodule is missing at $GHOSTTY_DIR" >&2
  exit 1
fi

build_helper() {
  local prefix="$1"
  local target="${2:-}"
  local zig_bin
  if ! zig_bin="$(select_zig_for_target "$target")"; then
    exit 1
  fi
  local zig_arch
  zig_arch="$(zig_binary_arch "$zig_bin")"
  local desired_arch
  desired_arch="$(target_arch_for_triple "$target")"
  local effective_target="$target"
  if [[ -n "$desired_arch" && "$zig_arch" == "$desired_arch" ]]; then
    # Native compilation avoids Zig 0.15.x cross-linker failures against newer
    # macOS SDKs while still producing the requested helper architecture.
    effective_target=""
  fi

  local args=(
    "$zig_bin"
    build
    cli-helper
    -Dapp-runtime=none
    -Dcrash-report-subdir=zerocmux/crash
    -Demit-macos-app=false
    -Demit-xcframework=false
    -Doptimize=ReleaseFast
    -Dsentry=false
    --prefix
    "$prefix"
  )

  if [[ -n "$effective_target" ]]; then
    args+=("-Dtarget=$effective_target")
  fi

  echo "Building Ghostty CLI helper with $zig_bin${target:+ for $target}"
  (
    cd "$GHOSTTY_DIR"
    if [[ -n "${ZIG_XCRUN_WRAPPER_DIR:-}" ]]; then
      PATH="$ZIG_XCRUN_WRAPPER_DIR:$PATH" ZIG_MACOS_SDKROOT="$ZIG_MACOS_SDKROOT" "${args[@]}"
    else
      "${args[@]}"
    fi
  )
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cmux-ghostty-helper.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
ZIG_XCRUN_WRAPPER_DIR=""
ZIG_MACOS_SDKROOT=""
prepare_zig_xcrun_wrapper

mkdir -p "$(dirname "$OUTPUT_PATH")"

if [[ "$UNIVERSAL" == "true" ]]; then
  ARM64_PREFIX="$TMP_DIR/arm64"
  X86_PREFIX="$TMP_DIR/x86_64"
  NATIVE_ZIG="$(select_zig_for_target "")"
  ZIG_ARCH="$(zig_binary_arch "$NATIVE_ZIG")"
  # Use native compilation for the matching arch to avoid cross-linker issues
  if [[ "$ZIG_ARCH" == "arm64" ]]; then
    build_helper "$ARM64_PREFIX" ""
    build_helper "$X86_PREFIX" "x86_64-macos"
  elif [[ "$ZIG_ARCH" == "x86_64" ]]; then
    build_helper "$ARM64_PREFIX" "aarch64-macos"
    build_helper "$X86_PREFIX" ""
  else
    build_helper "$ARM64_PREFIX" "aarch64-macos"
    build_helper "$X86_PREFIX" "x86_64-macos"
  fi
  /usr/bin/lipo -create \
    "$ARM64_PREFIX/bin/ghostty" \
    "$X86_PREFIX/bin/ghostty" \
    -output "$OUTPUT_PATH"
else
  SINGLE_PREFIX="$TMP_DIR/single"
  build_helper "$SINGLE_PREFIX" "$TARGET_TRIPLE"
  install -m 755 "$SINGLE_PREFIX/bin/ghostty" "$OUTPUT_PATH"
fi

chmod +x "$OUTPUT_PATH"
