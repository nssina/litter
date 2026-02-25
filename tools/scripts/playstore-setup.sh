#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="${PACKAGE_NAME:-com.sigkitten.litter.android}"
SERVICE_ACCOUNT_JSON="${SERVICE_ACCOUNT_JSON:-${PLAY_SERVICE_ACCOUNT_JSON:-}}"

usage() {
  cat <<'EOF'
Usage: ./tools/scripts/playstore-setup.sh [options]

Validates Play Console API access for a package using a service-account key.

Options:
      --package-name <id>         Android package name (default: com.sigkitten.litter.android)
      --service-account-json <p>  Path to Play service-account JSON key
  -h, --help                      Show this help

Environment fallbacks:
  PACKAGE_NAME
  SERVICE_ACCOUNT_JSON or PLAY_SERVICE_ACCOUNT_JSON
EOF
}

while [ "${1:-}" != "" ]; do
  case "$1" in
    --package-name)
      PACKAGE_NAME="${2:-}"
      if [ -z "$PACKAGE_NAME" ]; then
        echo "error: --package-name requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --service-account-json)
      SERVICE_ACCOUNT_JSON="${2:-}"
      if [ -z "$SERVICE_ACCOUNT_JSON" ]; then
        echo "error: --service-account-json requires a value" >&2
        exit 1
      fi
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

require_cmd fastlane

if [ -z "$SERVICE_ACCOUNT_JSON" ]; then
  echo "error: set SERVICE_ACCOUNT_JSON (or PLAY_SERVICE_ACCOUNT_JSON) to your key file path" >&2
  exit 1
fi

if [ ! -f "$SERVICE_ACCOUNT_JSON" ]; then
  echo "error: service-account JSON not found: $SERVICE_ACCOUNT_JSON" >&2
  exit 1
fi

echo "==> Validating Play API key access for package $PACKAGE_NAME"
fastlane run validate_play_store_json_key \
  json_key:"$SERVICE_ACCOUNT_JSON" >/dev/null

echo "==> Play API credentials look valid."
echo "    Package check is performed during upload (track edit against $PACKAGE_NAME)."
