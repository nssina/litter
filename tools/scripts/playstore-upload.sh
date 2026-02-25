#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PACKAGE_NAME="${PACKAGE_NAME:-com.sigkitten.litter.android}"
FLAVOR="${FLAVOR:-onDevice}"
TRACK="${TRACK:-internal}"
RELEASE_STATUS="${RELEASE_STATUS:-completed}"
BUILD_AAB="${BUILD_AAB:-1}"
SKIP_RUST="${SKIP_RUST:-0}"

SERVICE_ACCOUNT_JSON="${SERVICE_ACCOUNT_JSON:-${PLAY_SERVICE_ACCOUNT_JSON:-}}"
KEYSTORE_PATH="${KEYSTORE_PATH:-${ANDROID_KEYSTORE_PATH:-}}"
KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD:-${ANDROID_KEYSTORE_PASSWORD:-}}"
KEY_ALIAS="${KEY_ALIAS:-${ANDROID_KEY_ALIAS:-}}"
KEY_PASSWORD="${KEY_PASSWORD:-${ANDROID_KEY_PASSWORD:-}}"

AAB_PATH="${AAB_PATH:-}"

usage() {
  cat <<'EOF'
Usage: ./tools/scripts/playstore-upload.sh [options]

Builds a signed Android App Bundle (.aab) and uploads it to a Google Play track.

Options:
      --flavor <onDevice|remoteOnly>   Product flavor (default: onDevice)
      --track <internal|closed|open|production|customTrackId>
                                       Play track (default: internal)
      --release-status <completed|draft|inProgress|halted>
                                       Play release status (default: completed)
      --aab-path <path>                Existing .aab path (skips build unless --build-aab is set)
      --build-aab                      Force bundle build (default)
      --no-build-aab                   Skip bundle build and upload existing --aab-path
      --skip-rust                      Skip Android Rust bridge rebuild before bundle
      --package-name <id>              Android package id (default: com.sigkitten.litter.android)
      --service-account-json <path>    Play service-account JSON key
      --keystore-path <path>           Upload keystore path
      --keystore-password <value>      Upload keystore password
      --key-alias <value>              Upload key alias
      --key-password <value>           Upload key password
  -h, --help                           Show this help

Environment fallbacks:
  PACKAGE_NAME, FLAVOR, TRACK, RELEASE_STATUS, AAB_PATH
  SERVICE_ACCOUNT_JSON or PLAY_SERVICE_ACCOUNT_JSON
  KEYSTORE_PATH/ANDROID_KEYSTORE_PATH
  KEYSTORE_PASSWORD/ANDROID_KEYSTORE_PASSWORD
  KEY_ALIAS/ANDROID_KEY_ALIAS
  KEY_PASSWORD/ANDROID_KEY_PASSWORD
EOF
}

while [ "${1:-}" != "" ]; do
  case "$1" in
    --flavor)
      FLAVOR="${2:-}"
      shift 2
      ;;
    --track)
      TRACK="${2:-}"
      shift 2
      ;;
    --release-status)
      RELEASE_STATUS="${2:-}"
      shift 2
      ;;
    --aab-path)
      AAB_PATH="${2:-}"
      shift 2
      ;;
    --build-aab)
      BUILD_AAB=1
      shift
      ;;
    --no-build-aab)
      BUILD_AAB=0
      shift
      ;;
    --skip-rust)
      SKIP_RUST=1
      shift
      ;;
    --package-name)
      PACKAGE_NAME="${2:-}"
      shift 2
      ;;
    --service-account-json)
      SERVICE_ACCOUNT_JSON="${2:-}"
      shift 2
      ;;
    --keystore-path)
      KEYSTORE_PATH="${2:-}"
      shift 2
      ;;
    --keystore-password)
      KEYSTORE_PASSWORD="${2:-}"
      shift 2
      ;;
    --key-alias)
      KEY_ALIAS="${2:-}"
      shift 2
      ;;
    --key-password)
      KEY_PASSWORD="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: missing required command: $1" >&2
    exit 1
  fi
}

validate_choice() {
  local value="$1"
  shift
  for candidate in "$@"; do
    if [ "$value" = "$candidate" ]; then
      return
    fi
  done
  echo "error: invalid value '$value'" >&2
  exit 1
}

capitalize_first() {
  local raw="$1"
  local first="${raw:0:1}"
  local rest="${raw:1}"
  echo "$(tr '[:lower:]' '[:upper:]' <<<"$first")$rest"
}

require_cmd fastlane

validate_choice "$FLAVOR" onDevice remoteOnly
validate_choice "$RELEASE_STATUS" completed draft inProgress halted

track_api="$TRACK"
case "$TRACK" in
  internal)
    track_api="internal"
    ;;
  closed|alpha)
    track_api="alpha"
    ;;
  open|beta)
    track_api="beta"
    ;;
  production)
    track_api="production"
    ;;
  *)
    # Allow custom closed-testing track ids (for example, qa, dogfood).
    track_api="$TRACK"
    ;;
esac

if [ -z "$SERVICE_ACCOUNT_JSON" ]; then
  echo "error: set SERVICE_ACCOUNT_JSON (or PLAY_SERVICE_ACCOUNT_JSON) to your key file path" >&2
  exit 1
fi
if [ ! -f "$SERVICE_ACCOUNT_JSON" ]; then
  echo "error: service-account JSON not found: $SERVICE_ACCOUNT_JSON" >&2
  exit 1
fi

if [ "$BUILD_AAB" -eq 1 ]; then
  require_cmd gradle

  if [ "$SKIP_RUST" -eq 0 ] && [ "$FLAVOR" = "onDevice" ]; then
    echo "==> Rebuilding Android Rust bridge artifacts"
    "$REPO_DIR/tools/scripts/build-android-rust.sh"
  fi

  if [ -z "$KEYSTORE_PATH" ] || [ -z "$KEYSTORE_PASSWORD" ] || [ -z "$KEY_ALIAS" ] || [ -z "$KEY_PASSWORD" ]; then
    echo "error: signing inputs are required to build a Play-uploadable release AAB" >&2
    echo "       required: KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD" >&2
    exit 1
  fi
  if [ ! -f "$KEYSTORE_PATH" ]; then
    echo "error: keystore not found: $KEYSTORE_PATH" >&2
    exit 1
  fi

  flavor_task="$(capitalize_first "$FLAVOR")"
  bundle_task=":app:bundle${flavor_task}Release"

  echo "==> Building signed AAB ($bundle_task)"
  gradle -p "$REPO_DIR/apps/android" "$bundle_task" \
    -Pandroid.injected.signing.store.file="$KEYSTORE_PATH" \
    -Pandroid.injected.signing.store.password="$KEYSTORE_PASSWORD" \
    -Pandroid.injected.signing.key.alias="$KEY_ALIAS" \
    -Pandroid.injected.signing.key.password="$KEY_PASSWORD"

  if [ -z "$AAB_PATH" ]; then
    AAB_PATH="$REPO_DIR/apps/android/app/build/outputs/bundle/$FLAVOR"\
"/app-${FLAVOR}-release.aab"
  fi
fi

if [ -z "$AAB_PATH" ]; then
  echo "error: missing AAB path; set --aab-path or enable --build-aab" >&2
  exit 1
fi
if [ ! -f "$AAB_PATH" ]; then
  echo "error: AAB not found: $AAB_PATH" >&2
  exit 1
fi

echo "==> Uploading $AAB_PATH to Play track '$TRACK'"
fastlane supply \
  --aab "$AAB_PATH" \
  --package_name "$PACKAGE_NAME" \
  --track "$track_api" \
  --release_status "$RELEASE_STATUS" \
  --json_key "$SERVICE_ACCOUNT_JSON" \
  --skip_upload_metadata true \
  --skip_upload_images true \
  --skip_upload_screenshots true

echo "==> Play upload complete"
echo "    Package: $PACKAGE_NAME"
echo "    Flavor:  $FLAVOR"
echo "    Track:   $TRACK (api: $track_api)"
echo "    Status:  $RELEASE_STATUS"
echo "    AAB:     $AAB_PATH"
