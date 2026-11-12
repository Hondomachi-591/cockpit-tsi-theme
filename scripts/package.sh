#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=dev
if [ -f "$ROOT/VERSION" ]; then
    IFS= read -r VERSION < "$ROOT/VERSION"
fi
[ -n "$VERSION" ] || {
    printf '%s\n' "VERSION must not be empty" >&2
    exit 1
}
NAME="cockpit-tsi-theme-$VERSION"
DIST="$ROOT/dist"
STAGE="$DIST/$NAME"

rm -rf -- "${STAGE:?}"
mkdir -p "$STAGE"
cp "$ROOT/install.sh" "$STAGE/"
cp "$ROOT/README.md" "$STAGE/"
cp "$ROOT/LICENSE" "$STAGE/"
cp "$ROOT/VERSION" "$STAGE/"
cp "$ROOT/src/tspi-theme.css" "$STAGE/"

(
    cd "$DIST"
    tar -czf "$NAME.tar.gz" "$NAME"
)

rm -rf -- "${STAGE:?}"
printf 'Created %s\n' "$DIST/$NAME.tar.gz"
