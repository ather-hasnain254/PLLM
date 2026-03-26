#!/usr/bin/env bash
# ============================================================================
# PLLM-DY: ProVerif Installation Script
# ============================================================================
# ProVerif is NOT in standard apt repositories. This script installs it
# using one of three methods (in order of preference):
#
#   Method 1: OPAM (OCaml package manager) — recommended, cleanest
#   Method 2: Source build from official tarball
#   Method 3: Pre-built binary via Nix (if available)
#
# Usage:
#   chmod +x scripts/install_proverif.sh
#   ./scripts/install_proverif.sh
#
# Or step-by-step (Method 1 — OPAM):
#   sudo apt-get update
#   sudo apt-get install -y opam m4 gcc make
#   opam init --auto-setup --yes
#   eval $(opam env)
#   opam update
#   opam install proverif --yes
#   proverif --help
#
# Tested on: Ubuntu 20.04/22.04/24.04, Debian 11/12, WSL2, macOS 13+
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; }

# ── Check if ProVerif is already installed ──────────────────────────────────

if command -v proverif &> /dev/null; then
    ok "ProVerif is already installed:"
    proverif --help 2>&1 | head -2
    echo ""
    ok "You can verify the PLLM-DY models with:"
    echo "    proverif proverif/protocol_centralized.pv"
    echo "    proverif proverif/protocol_did.pv"
    echo "    proverif proverif/protocol_did_pllmdy.pv"
    exit 0
fi

# ── Detect OS ───────────────────────────────────────────────────────────────

OS="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
fi

info "Detected OS: $OS"
info "ProVerif is not in apt repositories. Installing via OPAM or source..."
echo ""

# ============================================================================
# METHOD 1: Install via OPAM (recommended)
# ============================================================================

install_via_opam() {
    info "═══════════════════════════════════════════════════════"
    info "  Method 1: Installing ProVerif via OPAM"
    info "═══════════════════════════════════════════════════════"

    # Step 1: Install system prerequisites
    if [[ "$OS" == "linux" ]]; then
        info "Installing system dependencies (requires sudo)..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq \
            opam ocaml m4 gcc make \
            pkg-config \
            graphviz \
            libgtk2.0-dev 2>/dev/null || true
    elif [[ "$OS" == "macos" ]]; then
        info "Installing via Homebrew..."
        if ! command -v brew &> /dev/null; then
            fail "Homebrew not found. Install from https://brew.sh"
            return 1
        fi
        brew install ocaml opam graphviz gtk+ 2>/dev/null || true
    fi

    # Step 2: Initialize OPAM (if not already)
    if [ ! -d "$HOME/.opam" ]; then
        info "Initializing OPAM (this takes a few minutes — compiles OCaml)..."
        opam init --auto-setup --yes --disable-sandboxing 2>&1 | tail -5
    else
        info "OPAM already initialized."
    fi

    # Step 3: Set up OPAM environment
    eval $(opam env --switch=default 2>/dev/null || opam env)

    # Step 4: Update and install ProVerif
    info "Updating OPAM package list..."
    opam update --yes 2>&1 | tail -3

    info "Installing ProVerif (this may take 2-5 minutes)..."
    opam install proverif --yes 2>&1 | tail -10

    # Step 5: Verify
    eval $(opam env)
    if command -v proverif &> /dev/null; then
        ok "ProVerif installed successfully via OPAM!"
        proverif --help 2>&1 | head -2
        return 0
    else
        warn "ProVerif binary not found in PATH after OPAM install."
        warn "You may need to run: eval \$(opam env)"
        return 1
    fi
}

# ============================================================================
# METHOD 2: Install from source tarball
# ============================================================================

install_from_source() {
    info "═══════════════════════════════════════════════════════"
    info "  Method 2: Installing ProVerif from source"
    info "═══════════════════════════════════════════════════════"

    PROVERIF_VERSION="2.05"
    PROVERIF_URL="https://bblanche.gitlabpages.inria.fr/proverif/proverif${PROVERIF_VERSION}.tar.gz"
    INSTALL_DIR="$HOME/proverif${PROVERIF_VERSION}"

    # Step 1: Install OCaml compiler
    if [[ "$OS" == "linux" ]]; then
        info "Installing OCaml and build tools..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq ocaml ocaml-findlib gcc make wget graphviz
    elif [[ "$OS" == "macos" ]]; then
        brew install ocaml wget graphviz 2>/dev/null || true
    fi

    # Verify OCaml version
    if ! command -v ocaml &> /dev/null; then
        fail "OCaml not found. Install it first:"
        echo "    sudo apt-get install ocaml"
        return 1
    fi

    OCAML_VER=$(ocaml -version 2>&1 | grep -oP '[\d]+\.[\d]+' | head -1)
    info "OCaml version: $OCAML_VER"

    # Step 2: Download ProVerif source
    info "Downloading ProVerif ${PROVERIF_VERSION}..."
    cd /tmp
    wget -q "$PROVERIF_URL" -O "proverif${PROVERIF_VERSION}.tar.gz"

    # Step 3: Extract and build
    info "Extracting..."
    tar -xzf "proverif${PROVERIF_VERSION}.tar.gz"
    cd "proverif${PROVERIF_VERSION}"

    info "Building ProVerif (this takes 1-3 minutes)..."
    ./build 2>&1 | tail -5

    # Step 4: Install to PATH
    if [ -f "./proverif" ]; then
        info "Copying binaries to /usr/local/bin/ (requires sudo)..."
        sudo cp proverif /usr/local/bin/proverif
        sudo cp proveriftotex /usr/local/bin/proveriftotex 2>/dev/null || true
        if [ -f "./proverif_interact" ]; then
            sudo cp proverif_interact /usr/local/bin/proverif_interact 2>/dev/null || true
        fi
        sudo chmod +x /usr/local/bin/proverif

        ok "ProVerif ${PROVERIF_VERSION} installed to /usr/local/bin/proverif"
        proverif --help 2>&1 | head -2
        return 0
    else
        fail "Build failed — proverif binary not found."
        echo "Check build errors above. Common fixes:"
        echo "  - Ensure OCaml >= 4.03: ocaml -version"
        echo "  - Install missing deps: sudo apt-get install ocaml-findlib"
        return 1
    fi
}

# ============================================================================
# Main: Try methods in order
# ============================================================================

echo "============================================================"
echo "  ProVerif Installation for PLLM-DY"
echo "============================================================"
echo ""
echo "ProVerif is NOT available via 'apt-get install proverif'."
echo "It must be installed via OPAM (OCaml package manager) or"
echo "built from source."
echo ""

# Try Method 1: OPAM
if command -v opam &> /dev/null || [[ "$OS" == "linux" ]] || [[ "$OS" == "macos" ]]; then
    install_via_opam
    if [ $? -eq 0 ]; then
        echo ""
        echo "============================================================"
        ok "Installation complete!"
        echo "============================================================"
        echo ""
        echo "  IMPORTANT: Add this to your ~/.bashrc or ~/.zshrc:"
        echo ""
        echo "    eval \$(opam env)"
        echo ""
        echo "  Then verify with:"
        echo "    proverif --help"
        echo ""
        echo "  Run the PLLM-DY protocol verification:"
        echo "    proverif proverif/protocol_centralized.pv"
        echo "    proverif proverif/protocol_did.pv"
        echo "    proverif proverif/protocol_did_pllmdy.pv"
        exit 0
    fi
fi

# Try Method 2: Source build
warn "OPAM method failed. Trying source build..."
install_from_source
if [ $? -eq 0 ]; then
    echo ""
    echo "============================================================"
    ok "Installation complete (from source)!"
    echo "============================================================"
    echo ""
    echo "  Run the PLLM-DY protocol verification:"
    echo "    proverif proverif/protocol_centralized.pv"
    echo "    proverif proverif/protocol_did.pv"
    echo "    proverif proverif/protocol_did_pllmdy.pv"
    exit 0
fi

# All methods failed
echo ""
fail "All installation methods failed."
echo ""
echo "  Manual installation options:"
echo ""
echo "  Option A — OPAM (recommended):"
echo "    sudo apt-get install opam m4 gcc make"
echo "    opam init --auto-setup --yes"
echo "    eval \$(opam env)"
echo "    opam update"
echo "    opam install proverif --yes"
echo "    eval \$(opam env)"
echo ""
echo "  Option B — Source build:"
echo "    sudo apt-get install ocaml gcc make wget"
echo "    wget https://bblanche.gitlabpages.inria.fr/proverif/proverif2.05.tar.gz"
echo "    tar xzf proverif2.05.tar.gz"
echo "    cd proverif2.05 && ./build"
echo "    sudo cp proverif /usr/local/bin/"
echo ""
echo "  Option C — Docker:"
echo "    docker run --rm -v \$(pwd)/proverif:/pv ocaml/opam:latest bash -c \\"
echo "      'opam install proverif -y && eval \$(opam env) && proverif /pv/protocol_did.pv'"
echo ""
exit 1
