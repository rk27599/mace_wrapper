#!/bin/bash
#
# MACE Wrapper - Deployment Package Creator
# Creates a portable tarball for deployment to other machines
#
# Usage: ./package_mace_wrapper.sh [--include-python] [--output DIR]
#
# Options:
#   --include-python  Include Python installation in package (~3.5GB)
#   --output DIR      Output directory (default: /tmp)
#
# Exit codes:
#   0 = Success
#   1 = Error

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PYTHON_INSTALL_DIR="$HOME/mace_python"
WRAPPER_DIR="$HOME/mace_wrapper"
OUTPUT_DIR="/tmp"
INCLUDE_PYTHON=false
PACKAGE_NAME="mace_wrapper_$(date +%Y%m%d_%H%M%S)"

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --include-python)
            INCLUDE_PYTHON=true
            shift
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--include-python] [--output DIR]"
            exit 1
            ;;
    esac
done

# Output functions
print_header() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_step() {
    echo -e "${GREEN}➜${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Start packaging
print_header "MACE Wrapper - Package Creator"
echo "Output: $OUTPUT_DIR/$PACKAGE_NAME.tar.gz"
echo "Include Python: $INCLUDE_PYTHON"
echo ""

# Create temporary directory
TEMP_DIR="/tmp/$PACKAGE_NAME"
mkdir -p "$TEMP_DIR"

# Check if WSL2
IS_WSL2=false
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    IS_WSL2=true
fi

# Package wrapper library
print_header "Packaging Wrapper Library"
print_step "Copying wrapper source..."
mkdir -p "$TEMP_DIR/mace_wrapper"
cp -r "$WRAPPER_DIR/include" "$TEMP_DIR/mace_wrapper/"
cp -r "$WRAPPER_DIR/src" "$TEMP_DIR/mace_wrapper/"
cp -r "$WRAPPER_DIR/python" "$TEMP_DIR/mace_wrapper/"
cp -r "$WRAPPER_DIR/test" "$TEMP_DIR/mace_wrapper/"

if [ -f "$WRAPPER_DIR/Makefile" ]; then
    cp "$WRAPPER_DIR/Makefile" "$TEMP_DIR/mace_wrapper/"
fi

# Copy built library if exists
if [ -d "$WRAPPER_DIR/lib" ]; then
    cp -r "$WRAPPER_DIR/lib" "$TEMP_DIR/mace_wrapper/"
    print_success "Pre-built library included"
fi

WRAPPER_SIZE=$(du -sh "$TEMP_DIR/mace_wrapper" | awk '{print $1}')
print_success "Wrapper library packaged ($WRAPPER_SIZE)"

# Package Python installation (optional)
if [ "$INCLUDE_PYTHON" = true ]; then
    print_header "Packaging Python Installation"

    if [ ! -d "$PYTHON_INSTALL_DIR" ]; then
        print_error "Python installation not found at $PYTHON_INSTALL_DIR"
        exit 1
    fi

    print_step "Copying Python installation (this may take a few minutes)..."
    mkdir -p "$TEMP_DIR/mace_python"
    cp -r "$PYTHON_INSTALL_DIR"/* "$TEMP_DIR/mace_python/"

    PYTHON_SIZE=$(du -sh "$TEMP_DIR/mace_python" | awk '{print $1}')
    print_success "Python installation packaged ($PYTHON_SIZE)"

    # Check if WSL2 patch was applied
    CACHE_MANAGER="$PYTHON_INSTALL_DIR/lib/python3.11/site-packages/cuequivariance_ops/triton/cache_manager.py"
    if [ -f "${CACHE_MANAGER}.backup" ]; then
        print_success "WSL2 patch detected - included in package"
    fi
else
    print_warning "Python installation not included (use --include-python to include)"
fi

# Package scripts
print_header "Packaging Scripts"
mkdir -p "$TEMP_DIR/scripts"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for script in detect_env.sh install_mace_wrapper.sh test_mace_wrapper.sh run_mace_app.sh; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        cp "$SCRIPT_DIR/$script" "$TEMP_DIR/scripts/"
        chmod +x "$TEMP_DIR/scripts/$script"
        print_step "Packaged: $script"
    fi
done

# Package documentation
print_header "Packaging Documentation"
mkdir -p "$TEMP_DIR/docs"

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
for doc in DEPENDENCY_ISSUES.md CUEQ_WSL2_INVESTIGATION.md PROJECT_STATUS_SUMMARY.md PHASE2_COMPLETE_SUMMARY.md; do
    if [ -f "$PROJECT_ROOT/$doc" ]; then
        cp "$PROJECT_ROOT/$doc" "$TEMP_DIR/docs/"
        print_step "Packaged: $doc"
    fi
done

# Create installation README
print_step "Creating installation README..."
cat > "$TEMP_DIR/README.md" << 'EOF'
# MACE Wrapper - Deployment Package

This package contains the MACE wrapper library for C++ integration with MACE machine learning potential.

## Package Contents

- `mace_wrapper/` - C++ wrapper library source and binaries
- `scripts/` - Installation and testing scripts
- `docs/` - Comprehensive documentation
EOF

if [ "$INCLUDE_PYTHON" = true ]; then
    cat >> "$TEMP_DIR/README.md" << 'EOF'
- `mace_python/` - Pre-configured Python 3.11 with MACE stack

## Quick Installation (Python Included)

This package includes a pre-built Python installation. Follow these steps:

1. **Extract Package:**
   ```bash
   tar -xzf mace_wrapper_*.tar.gz
   cd mace_wrapper_*
   ```

2. **Install Python:**
   ```bash
   mkdir -p ~/mace_python
   cp -r mace_python/* ~/mace_python/
   ```

3. **Install Wrapper:**
   ```bash
   mkdir -p ~/mace_wrapper
   cp -r mace_wrapper/* ~/mace_wrapper/
   ```

4. **Set up environment:**
   ```bash
   export LD_LIBRARY_PATH=~/mace_python/lib:$LD_LIBRARY_PATH
   export PYTHONPATH=~/mace_wrapper/python:$PYTHONPATH
   ```

5. **Test installation:**
   ```bash
   cd ~/mace_wrapper
   make test
   ```

## Quick Start (No Python)

If Python is not included, you'll need to install it first:

EOF
else
    cat >> "$TEMP_DIR/README.md" << 'EOF'

## Installation

1. **Extract Package:**
   ```bash
   tar -xzf mace_wrapper_*.tar.gz
   cd mace_wrapper_*
   ```

2. **Check Environment:**
   ```bash
   cd scripts
   chmod +x *.sh
   ./detect_env.sh
   ```

3. **Install Missing Dependencies:**
   Follow the instructions from detect_env.sh

4. **Run Full Installation:**
   ```bash
   ./install_mace_wrapper.sh
   ```

5. **Run Tests:**
   ```bash
   ./test_mace_wrapper.sh
   ```

EOF
fi

cat >> "$TEMP_DIR/README.md" << 'EOF'

## System Requirements

- **OS:** Ubuntu 20.04+ / RHEL 8+ / Rocky Linux 8+ or similar Linux distribution
- **CPU:** Any modern x86_64 processor
- **RAM:** 8GB minimum (16GB recommended)
- **Disk:** 15GB free space
- **GPU:** NVIDIA GPU with CUDA 11.8+ (optional, for GPU acceleration)

## WSL2 Limitations

If running on WSL2:
- ✅ All functionality works in CPU mode
- ⚠️ GPU acceleration limited (Triton kernels incompatible)
- 💡 For full GPU support, deploy to native Linux

## Usage Example

```c
#include "mace_wrapper.h"
#include <stdio.h>

int main() {
    // Initialize MACE
    MACEHandle mace = mace_init(NULL, "small", "cpu", 0);

    // H2O molecule
    double positions[] = {
        0.0, 0.0, 0.119,
        0.0, 0.763, -0.477,
        0.0, -0.763, -0.477
    };
    int atomic_numbers[] = {8, 1, 1};

    // Calculate
    MACEResult result;
    mace_calculate(mace, positions, atomic_numbers, 3, &result);

    if (result.success) {
        printf("Energy: %.6f eV\n", result.energy);
    }

    mace_cleanup(mace);
    return 0;
}
```

## Documentation

See `docs/` directory for comprehensive documentation:
- `PROJECT_STATUS_SUMMARY.md` - Complete project overview
- `DEPENDENCY_ISSUES.md` - All issues and solutions
- `CUEQ_WSL2_INVESTIGATION.md` - cuEquivariance investigation

## Support

For issues or questions, refer to the documentation or:
- MACE: https://github.com/ACEsuit/mace
- cuEquivariance: https://github.com/Linux-cpp-lisp/cuEquivariance

## License

This wrapper follows the same license as MACE (MIT License).
See original MACE repository for details.
EOF

print_success "README created"

# Create system info file
print_step "Creating system info..."
cat > "$TEMP_DIR/BUILD_INFO.txt" << EOF
MACE Wrapper Package Build Information
========================================

Build Date: $(date)
Build Host: $(hostname)
Build OS:   $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Build Kernel: $(uname -r)
WSL2: $IS_WSL2

Python Version: $($PYTHON_INSTALL_DIR/bin/python3 --version 2>/dev/null || echo "Not included")
Python Location: $PYTHON_INSTALL_DIR

Package Contents:
$(find "$TEMP_DIR" -type f | wc -l) files
$(du -sh "$TEMP_DIR" | awk '{print $1}') total size

Included Components:
- Wrapper library source
- Built shared library
- Test applications
- Build system (Makefile)
- Installation scripts
- Documentation

EOF

if [ "$INCLUDE_PYTHON" = true ]; then
    cat >> "$TEMP_DIR/BUILD_INFO.txt" << EOF
Python Packages:
$($PYTHON_INSTALL_DIR/bin/python3 -m pip list 2>/dev/null | grep -E "(torch|mace|cuequivariance|pybind11)")

EOF
fi

print_success "Build info created"

# Create tarball
print_header "Creating Archive"
cd /tmp

print_step "Compressing package..."
tar -czf "$OUTPUT_DIR/$PACKAGE_NAME.tar.gz" "$PACKAGE_NAME" 2>&1 | \
    grep -v "Removing leading" || true

PACKAGE_SIZE=$(du -sh "$OUTPUT_DIR/$PACKAGE_NAME.tar.gz" | awk '{print $1}')
print_success "Package created: $OUTPUT_DIR/$PACKAGE_NAME.tar.gz ($PACKAGE_SIZE)"

# Cleanup
print_step "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

# Summary
print_header "Package Complete!"
echo ""
echo "Package: $OUTPUT_DIR/$PACKAGE_NAME.tar.gz"
echo "Size: $PACKAGE_SIZE"
echo ""
echo "Contents:"
echo "  - Wrapper library (source + binaries)"
echo "  - Installation scripts"
echo "  - Test suite"
echo "  - Documentation"
if [ "$INCLUDE_PYTHON" = true ]; then
    echo "  - Python 3.11 with MACE stack"
fi
echo ""
echo "To deploy:"
echo "  1. Copy package to target machine"
echo "  2. tar -xzf $PACKAGE_NAME.tar.gz"
echo "  3. cd $PACKAGE_NAME"
echo "  4. Read README.md for instructions"
echo ""

if [ "$INCLUDE_PYTHON" = false ]; then
    print_warning "Python not included - target machine will need to install it"
    echo "To include Python (larger package):"
    echo "  $0 --include-python"
    echo ""
fi

print_success "Packaging successful!"
