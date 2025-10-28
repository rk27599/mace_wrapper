#!/bin/bash
#
# MACE Wrapper - Runtime Application Wrapper
# Sets up environment and runs applications using MACE wrapper library
#
# Usage: ./run_mace_app.sh <executable> [args...]
#        ./run_mace_app.sh --env  (print environment only)
#
# Examples:
#   ./run_mace_app.sh ./my_mace_app
#   ./run_mace_app.sh --env
#
# Exit codes:
#   0 = Success
#   1 = Configuration error
#   2 = Application error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PYTHON_INSTALL_DIR="$HOME/mace_python"
WRAPPER_DIR="$HOME/mace_wrapper"

# Output functions
print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}✓${NC} $1" >&2
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1" >&2
}

# Check installations
check_installation() {
    local errors=0

    if [ ! -d "$PYTHON_INSTALL_DIR" ]; then
        print_error "Python installation not found: $PYTHON_INSTALL_DIR"
        errors=$((errors + 1))
    fi

    if [ ! -x "$PYTHON_INSTALL_DIR/bin/python3" ]; then
        print_error "Python executable not found: $PYTHON_INSTALL_DIR/bin/python3"
        errors=$((errors + 1))
    fi

    if [ ! -d "$WRAPPER_DIR" ]; then
        print_error "Wrapper directory not found: $WRAPPER_DIR"
        errors=$((errors + 1))
    fi

    if [ ! -f "$WRAPPER_DIR/lib/libmace_wrapper.so" ]; then
        print_error "Wrapper library not found: $WRAPPER_DIR/lib/libmace_wrapper.so"
        errors=$((errors + 1))
    fi

    return $errors
}

# Set up environment
setup_environment() {
    # Python library path
    export LD_LIBRARY_PATH="$PYTHON_INSTALL_DIR/lib:${LD_LIBRARY_PATH}"

    # Wrapper library path
    export LD_LIBRARY_PATH="$WRAPPER_DIR/lib:${LD_LIBRARY_PATH}"

    # Python module path
    export PYTHONPATH="$WRAPPER_DIR/python:${PYTHONPATH}"

    # Python home (critical for pybind11)
    export PYTHONHOME="$PYTHON_INSTALL_DIR"
}

# Print environment
print_environment() {
    echo ""
    echo "MACE Wrapper Runtime Environment"
    echo "================================="
    echo ""
    echo "Python Installation:"
    echo "  Location: $PYTHON_INSTALL_DIR"
    if [ -x "$PYTHON_INSTALL_DIR/bin/python3" ]; then
        echo "  Version:  $($PYTHON_INSTALL_DIR/bin/python3 --version)"
    fi
    echo ""
    echo "Wrapper Library:"
    echo "  Location: $WRAPPER_DIR"
    if [ -f "$WRAPPER_DIR/lib/libmace_wrapper.so" ]; then
        echo "  Size:     $(du -h "$WRAPPER_DIR/lib/libmace_wrapper.so" | awk '{print $1}')"
    fi
    echo ""
    echo "Environment Variables:"
    echo "  LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
    echo "  PYTHONPATH:      $PYTHONPATH"
    echo "  PYTHONHOME:      $PYTHONHOME"
    echo ""
    echo "System Information:"
    echo "  OS:       $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "  Kernel:   $(uname -r)"

    if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
        echo "  Platform: WSL2"
        print_warning "WSL2 detected - GPU acceleration limited"
    else
        echo "  Platform: Native Linux"
    fi

    if command -v nvidia-smi &> /dev/null; then
        echo ""
        echo "GPU Information:"
        nvidia-smi --query-gpu=name,memory.total,driver_version,cuda_version --format=csv,noheader | \
            awk -F', ' '{print "  GPU:      " $1 "\n  VRAM:     " $2 "\n  Driver:   " $3 "\n  CUDA:     " $4}'
    else
        echo ""
        print_warning "No NVIDIA GPU detected - CPU mode only"
    fi

    echo ""
    echo "Python Packages:"
    $PYTHON_INSTALL_DIR/bin/python3 -m pip list 2>/dev/null | grep -E "(torch|mace|cuequivariance|pybind11)" | sed 's/^/  /'

    echo ""
}

# Main script
if [ $# -eq 0 ]; then
    print_error "No application specified"
    echo "Usage: $0 <executable> [args...]" >&2
    echo "       $0 --env  (print environment)" >&2
    exit 1
fi

# Check for --env flag
if [ "$1" == "--env" ]; then
    check_installation || {
        print_error "Installation check failed"
        exit 1
    }
    setup_environment
    print_environment
    exit 0
fi

# Check installation
if ! check_installation; then
    print_error "Installation check failed - cannot run application"
    echo "" >&2
    echo "Run installation:" >&2
    echo "  ./install_mace_wrapper.sh" >&2
    exit 1
fi

# Set up environment
setup_environment

# Get application path
APP="$1"
shift

# Check if application exists
if [ ! -f "$APP" ]; then
    print_error "Application not found: $APP"
    exit 1
fi

# Check if application is executable
if [ ! -x "$APP" ]; then
    print_error "Application not executable: $APP"
    echo "Try: chmod +x $APP" >&2
    exit 1
fi

# Run application
print_info "Running: $APP $@"
print_info "Environment configured"

# Execute application
exec "$APP" "$@"
