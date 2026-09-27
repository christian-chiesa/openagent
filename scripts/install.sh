#!/usr/bin/env bash
# OpenAgent installer — works on Linux, macOS, WSL
# Usage: curl -sSf https://openagent.sh | sh
#
# Environment variables:
#   OPENAGENT_INSTALL_DIR  — custom install directory (default: ~/.openagent/bin)
#   OPENAGENT_VERSION      — install a specific version tag (default: latest)

set -euo pipefail

REPO="RightNow-AI/openagent"
INSTALL_DIR="${OPENAGENT_INSTALL_DIR:-$HOME/.openagent/bin}"

detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64) ARCH="x86_64" ;;
        aarch64|arm64) ARCH="aarch64" ;;
        *) echo "  Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    case "$OS" in
        linux) PLATFORM="${ARCH}-unknown-linux-gnu" ;;
        darwin) PLATFORM="${ARCH}-apple-darwin" ;;
        mingw*|msys*|cygwin*)
            echo ""
            echo "  For Windows, use PowerShell instead:"
            echo "    irm https://openagent.sh/install.ps1 | iex"
            echo ""
            echo "  Or download the .msi installer from:"
            echo "    https://github.com/$REPO/releases/latest"
            echo ""
            echo "  Or install via cargo:"
            echo "    cargo install --git https://github.com/$REPO openagent-cli"
            exit 1
            ;;
        *) echo "  Unsupported OS: $OS"; exit 1 ;;
    esac
}

install() {
    detect_platform

    echo ""
    echo "  OpenAgent Installer"
    echo "  =================="
    echo ""

    # Get latest version with binary assets
    if [ -n "${OPENAGENT_VERSION:-}" ]; then
        VERSION="$OPENAGENT_VERSION"
        echo "  Using specified version: $VERSION"
    else
        echo "  Fetching latest release..."
        # Find the most recent release that has binary assets (skip empty tag-only releases)
        VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases?per_page=10" | \
            grep -E '"tag_name"|"assets":\[' | \
            paste - - | \
            grep -v '"assets":\[\]' | \
            head -1 | \
            sed 's/.*"tag_name": *"//' | sed 's/".*//')
        # Fallback to /releases/latest if the above fails
        if [ -z "$VERSION" ]; then
            VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"//' | sed 's/".*//')
        fi
    fi

    if [ -z "$VERSION" ]; then
        echo "  Could not determine latest version."
        echo "  Install from source instead:"
        echo "    cargo install --git https://github.com/$REPO openagent-cli"
        exit 1
    fi

    URL="https://github.com/$REPO/releases/download/$VERSION/openagent-$PLATFORM.tar.gz"
    CHECKSUM_URL="$URL.sha256"

    echo "  Installing OpenAgent $VERSION for $PLATFORM..."
    mkdir -p "$INSTALL_DIR"

    # Download to temp
    TMPDIR=$(mktemp -d)
    ARCHIVE="$TMPDIR/openagent.tar.gz"
    CHECKSUM_FILE="$TMPDIR/checksum.sha256"

    cleanup() { rm -rf "$TMPDIR"; }
    trap cleanup EXIT

    if ! curl -fsSL "$URL" -o "$ARCHIVE" 2>/dev/null; then
        echo "  Download failed. The release may not exist for your platform."
        echo "  Install from source instead:"
        echo "    cargo install --git https://github.com/$REPO openagent-cli"
        exit 1
    fi

    # Verify checksum if available
    if curl -fsSL "$CHECKSUM_URL" -o "$CHECKSUM_FILE" 2>/dev/null; then
        EXPECTED=$(cut -d ' ' -f 1 < "$CHECKSUM_FILE")
        if command -v sha256sum &>/dev/null; then
            ACTUAL=$(sha256sum "$ARCHIVE" | cut -d ' ' -f 1)
        elif command -v shasum &>/dev/null; then
            ACTUAL=$(shasum -a 256 "$ARCHIVE" | cut -d ' ' -f 1)
        else
            ACTUAL=""
        fi
        if [ -n "$ACTUAL" ]; then
            if [ "$EXPECTED" != "$ACTUAL" ]; then
                echo "  Checksum verification FAILED!"
                echo "    Expected: $EXPECTED"
                echo "    Got:      $ACTUAL"
                exit 1
            fi
            echo "  Checksum verified."
        else
            echo "  No sha256sum/shasum found, skipping checksum verification."
        fi
    fi

    # Extract
    tar xzf "$ARCHIVE" -C "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/openagent"

    # Ad-hoc codesign on macOS (prevents SIGKILL on Apple Silicon)
    # Must strip extended attributes (com.apple.quarantine) BEFORE signing,
    # otherwise the signature is computed over the quarantine xattr and macOS
    # rejects it as "Code Signature Invalid" → SIGKILL.
    if [ "$OS" = "darwin" ]; then
        if command -v xattr &>/dev/null; then
            xattr -cr "$INSTALL_DIR/openagent" 2>/dev/null || true
        fi
        if command -v codesign &>/dev/null; then
            if ! codesign --force --sign - "$INSTALL_DIR/openagent"; then
                echo ""
                echo "  Warning: ad-hoc code signing failed."
                echo "  On Apple Silicon, the binary may be killed (SIGKILL) by Gatekeeper."
                echo "  Try manually: xattr -cr $INSTALL_DIR/openagent && codesign --force --sign - $INSTALL_DIR/openagent"
                echo ""
            fi
        fi
    fi

    # Add to PATH — detect the user's login shell
    USER_SHELL="${SHELL:-}"
    # Fallback: check /etc/passwd if $SHELL is unset (e.g. minimal containers)
    if [ -z "$USER_SHELL" ] && command -v getent &>/dev/null; then
        USER_SHELL=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
    fi
    if [ -z "$USER_SHELL" ] && [ -f /etc/passwd ]; then
        USER_SHELL=$(grep "^$(id -un):" /etc/passwd 2>/dev/null | cut -d: -f7)
    fi

    # Fish shell: write to ~/.config/fish/conf.d/openagent.fish (drop-in dir).
    # This keeps the user's config.fish completely untouched, so a broken
    # PATH entry can never wedge the user's main shell config — critical
    # on Arch/CachyOS where the desktop session sources fish on login.
    USE_FISH_DROPIN=0
    case "$USER_SHELL" in
        */fish) USE_FISH_DROPIN=1 ;;
    esac
    # If $USER_SHELL didn't match fish but config.fish exists AND no other
    # rc files exist, the user is likely a fish user — use the drop-in too.
    if [ "$USE_FISH_DROPIN" -eq 0 ] \
        && [ -f "$HOME/.config/fish/config.fish" ] \
        && [ ! -f "$HOME/.bashrc" ] \
        && [ ! -f "$HOME/.zshrc" ]; then
        USE_FISH_DROPIN=1
    fi

    if [ "$USE_FISH_DROPIN" -eq 1 ]; then
        FISH_CONF_DIR="$HOME/.config/fish/conf.d"
        FISH_DROPIN="$FISH_CONF_DIR/openagent.fish"
        mkdir -p "$FISH_CONF_DIR"
        if [ ! -f "$FISH_DROPIN" ]; then
            # Guarded with `test -d` so a missing/broken install dir never
            # breaks fish startup (which would black-screen Arch/CachyOS
            # desktop sessions that source fish at login).
            cat > "$FISH_DROPIN" <<EOF
# OpenAgent PATH — auto-generated by installer
if test -d "$INSTALL_DIR"
    fish_add_path -g "$INSTALL_DIR"
end
EOF
            echo "  Added $INSTALL_DIR to PATH via $FISH_DROPIN"
        fi
        # Best-effort: clean up legacy bash-syntax export from config.fish
        # written by older OpenAgent installers (<v0.5.0). Harmless if absent.
        OLD_FISH_RC="$HOME/.config/fish/config.fish"
        if [ -f "$OLD_FISH_RC" ] && grep -q "openagent/bin" "$OLD_FISH_RC" 2>/dev/null; then
            # Remove any line containing .openagent/bin (covers both bash
            # `export PATH=` syntax and old fish `set -gx PATH` lines).
            TMPFILE=$(mktemp)
            grep -v "openagent/bin" "$OLD_FISH_RC" > "$TMPFILE" || true
            mv "$TMPFILE" "$OLD_FISH_RC"
            echo "  Cleaned legacy openagent PATH entry from $OLD_FISH_RC"
        fi
    else
        SHELL_RC=""
        case "$USER_SHELL" in
            */zsh)  SHELL_RC="$HOME/.zshrc" ;;
            */bash) SHELL_RC="$HOME/.bashrc" ;;
        esac
        # Fall back to existing rc files when shell detection failed.
        if [ -z "$SHELL_RC" ]; then
            if [ -f "$HOME/.bashrc" ]; then
                SHELL_RC="$HOME/.bashrc"
            elif [ -f "$HOME/.zshrc" ]; then
                SHELL_RC="$HOME/.zshrc"
            fi
        fi

        if [ -n "$SHELL_RC" ] && ! grep -q "openagent" "$SHELL_RC" 2>/dev/null; then
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$SHELL_RC"
            echo "  Added $INSTALL_DIR to PATH in $SHELL_RC"
        fi
    fi

    # Verify installation
    if "$INSTALL_DIR/openagent" --version >/dev/null 2>&1; then
        INSTALLED_VERSION=$("$INSTALL_DIR/openagent" --version 2>/dev/null || echo "$VERSION")
        echo ""
        echo "  OpenAgent installed successfully! ($INSTALLED_VERSION)"
    else
        echo ""
        echo "  OpenAgent binary installed to $INSTALL_DIR/openagent"
    fi

    echo ""
    echo "  Get started:"
    echo "    openagent init"
    echo ""
    echo "  The setup wizard will guide you through provider selection"
    echo "  and configuration."
    echo ""
}

install
