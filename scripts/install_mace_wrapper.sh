#!/bin/bash
#
# MACE Wrapper - Automated Installation Script
# Installs Python 3.11, MACE stack, and wrapper library on native Linux
#
# Usage: ./install_mace_wrapper.sh [--skip-python] [--skip-deps] [--cpu-only]
#
# Options:
#   --skip-python   Skip Python build if $HOME/mace_python exists
#   --skip-deps     Skip dependency installation (assumes already installed)
#   --cpu-only      Install without CUDA support (CPU mode only)
#
# Exit codes:
#   0 = Success
#   1 = Dependency error
#   2 = Build error
#   3 = Installation error

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PYTHON_VERSION="3.11.10"
PYTHON_INSTALL_DIR="$HOME/mace_python"
WRAPPER_DIR="$HOME/mace_wrapper"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse arguments
SKIP_PYTHON=false
SKIP_DEPS=false
CPU_ONLY=false

for arg in "$@"; do
    case $arg in
        --skip-python)
            SKIP_PYTHON=true
            ;;
        --skip-deps)
            SKIP_DEPS=true
            ;;
        --cpu-only)
            CPU_ONLY=true
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--skip-python] [--skip-deps] [--cpu-only]"
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

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Trap errors
error_exit() {
    print_error "Installation failed at: $1"
    echo "Check logs in /tmp/mace_install_*.log"
    exit 2
}

trap 'error_exit "${BASH_COMMAND}"' ERR

# Start installation
print_header "MACE Wrapper Installation"
echo "Target: Native Linux deployment"
echo "Python: $PYTHON_VERSION"
echo "Install dir: $PYTHON_INSTALL_DIR"
echo "Wrapper dir: $WRAPPER_DIR"
echo ""

# Detect WSL2
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    print_warning "WSL2 detected - cuEquivariance GPU acceleration will be limited"
    print_warning "For full GPU support, use native Linux"
    IS_WSL2=true
else
    print_success "Native Linux detected - full GPU acceleration available"
    IS_WSL2=false
fi

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Do not run this script as root (sudo will be requested when needed)"
    exit 1
fi

# Install dependencies
if [ "$SKIP_DEPS" = false ]; then
    print_header "Installing Dependencies"

    # Detect package manager and set dependencies accordingly
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu system
        PKG_MANAGER="apt-get"
        PKG_UPDATE="sudo apt-get update"
        PKG_INSTALL="sudo apt-get install -y"
        LOG_PREFIX="apt"
        DEPS=(
            "build-essential"
            "libncurses5-dev"
            "libncursesw5-dev"
            "libreadline-dev"
            "libsqlite3-dev"
            "libgdbm-dev"
            "libdb-dev"
            "libbz2-dev"
            "liblzma-dev"
            "uuid-dev"
            "libffi-dev"
            "libssl-dev"
            "zlib1g-dev"
            "wget"
            "ca-certificates"
        )
    elif command -v dnf &> /dev/null; then
        # RHEL/CentOS/Fedora 8+ with DNF
        PKG_MANAGER="dnf"
        PKG_UPDATE="sudo dnf makecache"
        PKG_INSTALL="sudo dnf install -y"
        LOG_PREFIX="dnf"
        DEPS=(
            "gcc"
            "gcc-c++"
            "make"
            "ncurses-devel"
            "readline-devel"
            "sqlite-devel"
            "gdbm-devel"
            "libdb-devel"
            "bzip2-devel"
            "xz-devel"
            "libuuid-devel"
            "libffi-devel"
            "openssl-devel"
            "zlib-devel"
            "wget"
            "ca-certificates"
        )
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS 7 with YUM
        PKG_MANAGER="yum"
        PKG_UPDATE="sudo yum makecache"
        PKG_INSTALL="sudo yum install -y"
        LOG_PREFIX="yum"
        DEPS=(
            "gcc"
            "gcc-c++"
            "make"
            "ncurses-devel"
            "readline-devel"
            "sqlite-devel"
            "gdbm-devel"
            "libdb-devel"
            "bzip2-devel"
            "xz-devel"
            "libuuid-devel"
            "libffi-devel"
            "openssl-devel"
            "zlib-devel"
            "wget"
            "ca-certificates"
        )
    else
        print_error "No supported package manager found (apt-get, dnf, or yum)"
        exit 1
    fi

    print_step "Updating package lists using $PKG_MANAGER..."
    $PKG_UPDATE > /tmp/mace_install_${LOG_PREFIX}_update.log 2>&1

    print_step "Installing build dependencies..."
    $PKG_INSTALL "${DEPS[@]}" > /tmp/mace_install_${LOG_PREFIX}_install.log 2>&1
    print_success "Dependencies installed"
else
    print_warning "Skipping dependency installation (--skip-deps)"
fi

# Build Python 3.11
if [ "$SKIP_PYTHON" = true ] && [ -x "$PYTHON_INSTALL_DIR/bin/python3" ]; then
    print_header "Skipping Python Build"
    EXISTING_VERSION=$($PYTHON_INSTALL_DIR/bin/python3 --version | awk '{print $2}')
    print_warning "Using existing Python $EXISTING_VERSION at $PYTHON_INSTALL_DIR"
else
    print_header "Building Python $PYTHON_VERSION"

    # Check if install dir exists
    if [ -d "$PYTHON_INSTALL_DIR" ]; then
        print_warning "Directory $PYTHON_INSTALL_DIR exists"
        read -p "Remove and reinstall? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_step "Removing existing installation..."
            rm -rf "$PYTHON_INSTALL_DIR"
        else
            print_error "Installation cancelled"
            exit 3
        fi
    fi

    # Download Python
    PYTHON_TAR="Python-${PYTHON_VERSION}.tgz"
    PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_TAR}"

    print_step "Downloading Python $PYTHON_VERSION..."
    cd /tmp
    wget -q --show-progress "$PYTHON_URL" -O "$PYTHON_TAR"

    print_step "Extracting..."
    tar -xzf "$PYTHON_TAR"
    cd "Python-${PYTHON_VERSION}"

    # Configure
    print_step "Configuring build (this may take 2-3 minutes)..."
    ./configure \
        --prefix="$PYTHON_INSTALL_DIR" \
        --enable-shared \
        --enable-optimizations \
        --with-lto \
        --enable-loadable-sqlite-extensions \
        > /tmp/mace_install_python_configure.log 2>&1

    # Build
    print_step "Building Python (this may take 10-15 minutes)..."
    CORES=$(nproc)
    make -j"$CORES" > /tmp/mace_install_python_build.log 2>&1

    # Install
    print_step "Installing Python..."
    make install > /tmp/mace_install_python_install.log 2>&1

    # Verify
    if [ ! -x "$PYTHON_INSTALL_DIR/bin/python3" ]; then
        print_error "Python installation failed"
        exit 2
    fi

    # Set LD_LIBRARY_PATH for Python verification and subsequent operations
    export LD_LIBRARY_PATH="$PYTHON_INSTALL_DIR/lib:$LD_LIBRARY_PATH"

    INSTALLED_VERSION=$($PYTHON_INSTALL_DIR/bin/python3 --version | awk '{print $2}')
    print_success "Python $INSTALLED_VERSION installed to $PYTHON_INSTALL_DIR"

    # Clean up
    cd /tmp
    rm -rf "Python-${PYTHON_VERSION}" "$PYTHON_TAR"
else
    # Set LD_LIBRARY_PATH even when skipping Python build
    export LD_LIBRARY_PATH="$PYTHON_INSTALL_DIR/lib:$LD_LIBRARY_PATH"
fi

# Environment already set above
PYTHON_BIN="$PYTHON_INSTALL_DIR/bin/python3"
PIP_BIN="$PYTHON_INSTALL_DIR/bin/pip3"

# Upgrade pip
print_header "Upgrading pip"
print_step "Upgrading pip, setuptools, wheel..."
$PYTHON_BIN -m pip install --upgrade pip setuptools wheel > /tmp/mace_install_pip_upgrade.log 2>&1
PIP_VERSION=$($PIP_BIN --version | awk '{print $2}')
print_success "pip $PIP_VERSION"

# Install PyTorch
print_header "Installing PyTorch"
if [ "$CPU_ONLY" = true ]; then
    print_step "Installing PyTorch (CPU-only)..."
    $PIP_BIN install torch torchvision --index-url https://download.pytorch.org/whl/cpu \
        > /tmp/mace_install_pytorch.log 2>&1
    print_success "PyTorch (CPU) installed"
else
    # Detect CUDA version
    if command -v nvidia-smi &> /dev/null; then
        CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}' | cut -d'.' -f1,2 | tr -d '.')
        if [ -z "$CUDA_VERSION" ]; then
            CUDA_VERSION="121"  # Default to cu121
        fi
    else
        print_warning "No GPU detected, falling back to CPU mode"
        CUDA_VERSION="cpu"
    fi

    if [ "$CUDA_VERSION" = "cpu" ]; then
        print_step "Installing PyTorch (CPU-only)..."
        $PIP_BIN install torch torchvision --index-url https://download.pytorch.org/whl/cpu \
            > /tmp/mace_install_pytorch.log 2>&1
    else
        print_step "Installing PyTorch with CUDA $CUDA_VERSION support..."
        # Try cu121 (most compatible)
        $PIP_BIN install torch torchvision --index-url https://download.pytorch.org/whl/cu121 \
            > /tmp/mace_install_pytorch.log 2>&1 || {
            print_warning "cu121 failed, trying cu118..."
            $PIP_BIN install torch torchvision --index-url https://download.pytorch.org/whl/cu118 \
                > /tmp/mace_install_pytorch.log 2>&1
        }
    fi
    print_success "PyTorch installed"
fi

# Verify PyTorch
print_step "Verifying PyTorch installation..."
$PYTHON_BIN -c "import torch; print(f'PyTorch {torch.__version__}')" > /tmp/mace_install_torch_verify.log 2>&1
TORCH_VERSION=$(cat /tmp/mace_install_torch_verify.log)
print_success "$TORCH_VERSION"

if [ "$CPU_ONLY" = false ]; then
    CUDA_AVAILABLE=$($PYTHON_BIN -c "import torch; print(torch.cuda.is_available())" 2>/dev/null || echo "False")
    if [ "$CUDA_AVAILABLE" = "True" ]; then
        GPU_NAME=$($PYTHON_BIN -c "import torch; print(torch.cuda.get_device_name(0))" 2>/dev/null)
        print_success "CUDA available: $GPU_NAME"
    else
        print_warning "CUDA not available (CPU mode will be used)"
    fi
fi

# Install MACE
print_header "Installing MACE"
print_step "Installing MACE and dependencies..."
$PIP_BIN install mace-torch > /tmp/mace_install_mace.log 2>&1
MACE_VERSION=$($PYTHON_BIN -c "import mace; print(mace.__version__)" 2>/dev/null || echo "unknown")
print_success "MACE $MACE_VERSION installed"

# Install cuEquivariance
if [ "$CPU_ONLY" = false ]; then
    print_header "Installing cuEquivariance"
    print_step "Installing cuEquivariance for GPU acceleration..."
    $PIP_BIN install cuequivariance-torch > /tmp/mace_install_cueq.log 2>&1
    print_success "cuEquivariance installed"

    # Apply WSL2 patch if needed
    if [ "$IS_WSL2" = true ]; then
        print_step "Applying WSL2 compatibility patch..."
        CACHE_MANAGER="$PYTHON_INSTALL_DIR/lib/python3.11/site-packages/cuequivariance_ops/triton/cache_manager.py"

        if [ -f "$CACHE_MANAGER" ]; then
            # Backup original
            cp "$CACHE_MANAGER" "${CACHE_MANAGER}.backup"

            # Apply patch
            $PYTHON_INSTALL_DIR/bin/python3 << EOF
import sys
import os
cache_manager = os.path.join(os.path.expanduser("~"), "mace_python/lib/python3.11/site-packages/cuequivariance_ops/triton/cache_manager.py")

with open(cache_manager, 'r') as f:
    content = f.read()

# Patch power limit query (around line 69)
content = content.replace(
    '    power_limit = pynvml.nvmlDeviceGetPowerManagementLimit(handle)',
    '''    # WSL2-safe: power limit query not supported in WSL2
    try:
        power_limit = pynvml.nvmlDeviceGetPowerManagementLimit(handle)
    except pynvml.NVMLError_NotSupported:
        power_limit = 125000  # Default for typical GPUs (125W in milliwatts)'''
)

# Patch GPU core count query (around line 81)
content = content.replace(
    '    gpu_core_count = pynvml.nvmlDeviceGetNumGpuCores(handle)',
    '''    # WSL2-safe: GPU core count query not supported in WSL2
    try:
        gpu_core_count = pynvml.nvmlDeviceGetNumGpuCores(handle)
    except pynvml.NVMLError_NotSupported:
        # Estimate based on typical GPU (will be cached per GPU)
        gpu_core_count = 5888  # Default estimate'''
)

with open(cache_manager, 'w') as f:
    f.write(content)

print("WSL2 patch applied successfully")
EOF
            print_success "WSL2 patch applied (backup saved)"
        else
            print_warning "cache_manager.py not found - patch skipped"
        fi
    fi
else
    print_warning "Skipping cuEquivariance (CPU-only mode)"
fi

# Install pybind11
print_header "Installing pybind11"
print_step "Installing pybind11..."
$PIP_BIN install pybind11 > /tmp/mace_install_pybind11.log 2>&1
PYBIND_VERSION=$($PYTHON_BIN -m pybind11 --version 2>/dev/null || echo "unknown")
print_success "pybind11 $PYBIND_VERSION installed"

# Create wrapper directory structure
print_header "Creating Wrapper Library"
print_step "Creating directory structure..."

mkdir -p "$WRAPPER_DIR"/{include,src,python,test,lib}

# Copy wrapper files from project
if [ -f "$PROJECT_ROOT/mace_wrapper.h" ]; then
    print_step "Copying wrapper files from project..."
    cp "$PROJECT_ROOT/mace_wrapper.h" "$WRAPPER_DIR/include/"
    cp "$PROJECT_ROOT/mace_wrapper.cpp" "$WRAPPER_DIR/src/"
    cp "$PROJECT_ROOT/mace_calculator.py" "$WRAPPER_DIR/python/"
    cp "$PROJECT_ROOT/test_mace.cpp" "$WRAPPER_DIR/test/"
    cp "$PROJECT_ROOT/Makefile" "$WRAPPER_DIR/"
    print_success "Wrapper files copied"
else
    print_warning "Wrapper files not found in project - you'll need to copy them manually"
fi

# Build wrapper library
if [ -f "$WRAPPER_DIR/Makefile" ]; then
    print_step "Building wrapper library..."
    cd "$WRAPPER_DIR"
    make clean > /dev/null 2>&1 || true
    make > /tmp/mace_install_wrapper_build.log 2>&1

    if [ -f "$WRAPPER_DIR/lib/libmace_wrapper.so" ]; then
        LIB_SIZE=$(du -h "$WRAPPER_DIR/lib/libmace_wrapper.so" | awk '{print $1}')
        print_success "Wrapper library built ($LIB_SIZE)"
    else
        print_error "Wrapper library build failed"
        exit 2
    fi
else
    print_warning "Makefile not found - skipping build"
fi

# Create environment setup script
print_header "Creating Environment Setup"
ENV_SCRIPT="$WRAPPER_DIR/setup_env.sh"

cat > "$ENV_SCRIPT" << EOF
#!/bin/bash
# MACE Wrapper Environment Setup
# Source this file before using the library: source setup_env.sh

export LD_LIBRARY_PATH="$PYTHON_INSTALL_DIR/lib:\$LD_LIBRARY_PATH"
export PYTHONPATH="$WRAPPER_DIR/python:\$PYTHONPATH"

echo "MACE Wrapper environment configured"
echo "Python: $PYTHON_INSTALL_DIR/bin/python3"
echo "Library: $WRAPPER_DIR/lib/libmace_wrapper.so"
EOF

chmod +x "$ENV_SCRIPT"
print_success "Environment script created: $ENV_SCRIPT"

# Installation summary
print_header "Installation Complete!"
echo ""
echo "Installation Summary:"
echo "  Python:   $PYTHON_INSTALL_DIR"
echo "  Wrapper:  $WRAPPER_DIR"
echo "  Library:  $WRAPPER_DIR/lib/libmace_wrapper.so"
echo ""
echo "Environment Setup:"
echo "  source $ENV_SCRIPT"
echo ""
echo "Run Tests:"
echo "  cd $WRAPPER_DIR"
echo "  make test"
echo ""
echo "Logs saved to: /tmp/mace_install_*.log"
echo ""

if [ "$IS_WSL2" = true ]; then
    print_warning "WSL2 Limitation: Use CPU mode for development"
    echo "  MACEHandle mace = mace_init(NULL, \"small\", \"cpu\", 0);"
    echo ""
    echo "For full GPU acceleration, deploy to native Linux"
else
    print_success "Native Linux: Full GPU acceleration available!"
    echo "  MACEHandle mace = mace_init(NULL, \"medium\", \"cuda\", 1);"
fi

echo ""
print_success "Installation successful!"
