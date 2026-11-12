#!/bin/sh
set -eu

ACTION="${1:-install}"
COCKPIT_ROOT="${COCKPIT_DATA_DIR:-/usr/share/cockpit}"
THEME_DIR="$COCKPIT_ROOT/static"
THEME_FILE="$THEME_DIR/tspi-theme.css"
BACKUP_DIR="/var/lib/cockpit-tsi-theme/originals"
SYSTEM_SCRIPT="/usr/local/sbin/cockpit-tsi-theme"
APT_HOOK="/etc/apt/apt.conf.d/99cockpit-tsi-theme"
THEME_TAG='<link rel="stylesheet" href="/cockpit/static/tspi-theme.css" data-tsi-theme="1">'
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERSION=dev
if [ -f "$HERE/VERSION" ]; then
    IFS= read -r VERSION < "$HERE/VERSION"
fi

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

need_root() {
    [ "$(id -u)" -eq 0 ] || die "run this script with sudo"
}

check_cockpit() {
    [ -d "$COCKPIT_ROOT" ] ||
        die "Cockpit data directory not found: $COCKPIT_ROOT"
    [ -f "$COCKPIT_ROOT/shell/index.html" ] ||
        die "Cockpit shell not found under $COCKPIT_ROOT"
}

theme_source() {
    if [ -f "$HERE/src/tspi-theme.css" ]; then
        printf '%s\n' "$HERE/src/tspi-theme.css"
    elif [ -f "$HERE/tspi-theme.css" ]; then
        printf '%s\n' "$HERE/tspi-theme.css"
    elif [ -f "$THEME_FILE" ]; then
        printf '%s\n' "$THEME_FILE"
    else
        die "theme CSS not found"
    fi
}

show_version() {
    printf 'Cockpit TSPI Theme: %s\n' "$VERSION"
    if command -v cockpit-bridge >/dev/null 2>&1; then
        cockpit-bridge --version | sed -n '1,2p'
        printf '%s\n' "Designed and tested with Cockpit 287 / PatternFly 4."
    else
        printf '%s\n' "cockpit-bridge not found; install Cockpit first." >&2
    fi
}

html_files() {
    find "$COCKPIT_ROOT" -type f -name '*.html' \
        ! -path '*/temperature/*' \
        -print
}

backup_file() {
    file=$1
    backup_name=$(printf '%s' "$file" | sed 's#^/##; s#/#__#g')
    if [ ! -f "$BACKUP_DIR/$backup_name" ]; then
        cp -a "$file" "$BACKUP_DIR/$backup_name"
    fi
}

inject_file() {
    file=$1
    if grep -q 'data-tsi-theme="1"' "$file"; then
        return
    fi

    backup_file "$file"
    temporary="$file.tsi-theme-new"
    TSI_THEME_LINE="$THEME_TAG" awk '
        /<\/head>/ && !done {
            print ENVIRON["TSI_THEME_LINE"]
            done = 1
        }
        { print }
    ' "$file" > "$temporary"

    mode=$(stat -c '%a' "$file" 2>/dev/null || printf '644')
    chmod "$mode" "$temporary"
    mv "$temporary" "$file"
}

remove_from_file() {
    file=$1
    if ! grep -q 'data-tsi-theme="1"' "$file"; then
        return
    fi

    temporary="$file.tsi-theme-new"
    grep -v 'data-tsi-theme="1"' "$file" > "$temporary" || true
    mode=$(stat -c '%a' "$file" 2>/dev/null || printf '644')
    chmod "$mode" "$temporary"
    mv "$temporary" "$file"
}

install_apt_hook() {
    [ -d /etc/apt/apt.conf.d ] || return
    if [ "$0" != "$SYSTEM_SCRIPT" ]; then
        install -m 0755 "$0" "$SYSTEM_SCRIPT"
    fi
    printf '%s\n' \
        'DPkg::Post-Invoke {' \
        '  "/usr/local/sbin/cockpit-tsi-theme install >/dev/null 2>&1 || true";' \
        '};' > "$APT_HOOK"
}

restart_cockpit() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl try-restart cockpit.socket >/dev/null 2>&1 || true
    fi
}

install_theme() {
    need_root
    check_cockpit
    mkdir -p "$THEME_DIR" "$BACKUP_DIR"
    source_file=$(theme_source)
    if [ "$source_file" != "$THEME_FILE" ]; then
        install -m 0644 "$source_file" "$THEME_FILE"
    fi

    html_files | while IFS= read -r file; do
        inject_file "$file"
    done

    install_apt_hook
    restart_cockpit
    printf 'Cockpit TSPI Theme %s installed.\n' "$VERSION"
    printf '%s\n' "Open https://SERVER_IP:9090 and force-reload the browser."
}

remove_theme() {
    need_root
    check_cockpit

    html_files | while IFS= read -r file; do
        remove_from_file "$file"
    done

    rm -f "$THEME_FILE" "$SYSTEM_SCRIPT" "$APT_HOOK"
    restart_cockpit
    printf 'Cockpit TSPI Theme %s removed.\n' "$VERSION"
    printf 'Original HTML backups remain in %s\n' "$BACKUP_DIR"
}

case "$ACTION" in
    install)
        install_theme
        ;;
    remove|uninstall)
        remove_theme
        ;;
    version|check)
        show_version
        ;;
    -h|--help|help)
        printf 'usage: %s [install|remove|version]\n' "$0"
        ;;
    *)
        die "unknown action: $ACTION"
        ;;
esac
