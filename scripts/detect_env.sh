#!/bin/bash
#
# MACE Wrapper - Environment Detection Script
# Detects system capabilities and checks for required dependencies
#
# Usage: ./detect_env.sh [--json]
#
# Exit codes:
#   0 = All requirements met
#   1 = Missing critical dependencies
#   2 = System incompatible

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# JSON output flag
JSON_OUTPUT=false
if [ "$1" == "--json" ]; then
    JSON_OUTPUT=true
fi

# Output functions
print_header() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${BLUE}=== $1 ===${NC}"
    fi
}

print_success() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✓${NC} $1"
    fi
}

print_warning() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${YELLOW}⚠${NC} $1"
    fi
}

print_error() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}✗${NC} $1"
    fi
}

# Initialize results
MISSING_DEPS=()
WARNINGS=()
SYSTEM_INFO=()

# Detect OS
print_header "Operating System"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="$NAME"
    OS_VERSION="$VERSION_ID"
    print_success "OS: $OS_NAME $OS_VERSION"
    SYSTEM_INFO+=("os_name:$OS_NAME")
    SYSTEM_INFO+=("os_version:$OS_VERSION")
else
    print_error "Cannot detect OS"
    exit 2
fi

# Detect if WSL2
IS_WSL2=false
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    IS_WSL2=true
    print_warning "Running in WSL2 - cuEquivariance GPU acceleration limited"
    WARNINGS+=("wsl2_detected:Triton CUDA kernels may not work")
    SYSTEM_INFO+=("wsl2:true")
else
    print_success "Native Linux detected - full GPU acceleration available"
    SYSTEM_INFO+=("wsl2:false")
fi

# Detect CPU
print_header "CPU Information"
CPU_MODEL=$(lscpu | grep "Model name" | sed 's/Model name: *//')
CPU_CORES=$(nproc)
print_success "CPU: $CPU_MODEL"
print_success "Cores: $CPU_CORES"
SYSTEM_INFO+=("cpu_model:$CPU_MODEL")
SYSTEM_INFO+=("cpu_cores:$CPU_CORES")

# Detect RAM
print_header "Memory"
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
print_success "RAM: ${TOTAL_RAM_GB}GB"
SYSTEM_INFO+=("ram_gb:$TOTAL_RAM_GB")

if [ $TOTAL_RAM_GB -lt 8 ]; then
    print_warning "Less than 8GB RAM - may limit model size"
    WARNINGS+=("low_ram:Less than 8GB available")
fi

# Detect GPU
print_header "GPU Information"
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "Unknown")
    GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null || echo "0")
    GPU_MEMORY_GB=$((GPU_MEMORY / 1024))

    print_success "GPU: $GPU_NAME"
    print_success "VRAM: ${GPU_MEMORY_GB}GB"
    SYSTEM_INFO+=("gpu_name:$GPU_NAME")
    SYSTEM_INFO+=("gpu_vram_gb:$GPU_MEMORY_GB")

    if [ $GPU_MEMORY_GB -lt 8 ]; then
        print_warning "Less than 8GB VRAM - use 'small' model only"
        WARNINGS+=("low_vram:Use small model only")
    fi
else
    print_warning "No NVIDIA GPU detected - CPU mode only"
    WARNINGS+=("no_gpu:CPU mode only")
    SYSTEM_INFO+=("gpu_name:None")
    SYSTEM_INFO+=("gpu_vram_gb:0")
fi

# Detect CUDA
print_header "CUDA"
if command -v nvcc &> /dev/null; then
    CUDA_VERSION=$(nvcc --version | grep "release" | sed 's/.*release //' | sed 's/,.*//')
    print_success "CUDA: $CUDA_VERSION"
    SYSTEM_INFO+=("cuda_version:$CUDA_VERSION")
else
    if command -v nvidia-smi &> /dev/null; then
        CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}')
        if [ -n "$CUDA_VERSION" ]; then
            print_success "CUDA: $CUDA_VERSION (driver-only)"
            SYSTEM_INFO+=("cuda_version:$CUDA_VERSION")
        else
            print_warning "CUDA not detected"
            WARNINGS+=("no_cuda:CUDA toolkit not found")
            SYSTEM_INFO+=("cuda_version:None")
        fi
    else
        print_warning "CUDA not detected"
        WARNINGS+=("no_cuda:CUDA toolkit not found")
        SYSTEM_INFO+=("cuda_version:None")
    fi
fi

# Detect GCC
print_header "Build Tools"
if command -v gcc &> /dev/null; then
    GCC_VERSION=$(gcc --version | head -n1 | awk '{print $NF}')
    print_success "GCC: $GCC_VERSION"
    SYSTEM_INFO+=("gcc_version:$GCC_VERSION")
else
    print_error "GCC not found"
    MISSING_DEPS+=("gcc")
fi

if command -v g++ &> /dev/null; then
    GXX_VERSION=$(g++ --version | head -n1 | awk '{print $NF}')
    print_success "G++: $GXX_VERSION"
    SYSTEM_INFO+=("gxx_version:$GXX_VERSION")
else
    print_error "G++ not found"
    MISSING_DEPS+=("g++")
fi

if command -v make &> /dev/null; then
    MAKE_VERSION=$(make --version | head -n1 | awk '{print $NF}')
    print_success "Make: $MAKE_VERSION"
    SYSTEM_INFO+=("make_version:$MAKE_VERSION")
else
    print_error "Make not found"
    MISSING_DEPS+=("make")
fi

# Check disk space
print_header "Disk Space"
AVAILABLE_GB=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
print_success "Available: ${AVAILABLE_GB}GB"
SYSTEM_INFO+=("disk_available_gb:$AVAILABLE_GB")

REQUIRED_GB=15
if [ $AVAILABLE_GB -lt $REQUIRED_GB ]; then
    print_error "Insufficient disk space (need ${REQUIRED_GB}GB, have ${AVAILABLE_GB}GB)"
    exit 2
fi

# Check Python build dependencies
print_header "Python Build Dependencies"

# Detect package manager and set dependencies accordingly
if command -v dpkg &> /dev/null; then
    # Debian/Ubuntu system
    PKG_CHECK_CMD="dpkg -l | grep -q \"^ii  \$dep\""
    PKG_MANAGER="apt-get"
    PYTHON_DEPS=(
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
    )
elif command -v rpm &> /dev/null; then
    # RHEL/CentOS/Fedora system
    PKG_CHECK_CMD="rpm -q \$dep &> /dev/null"
    if command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    else
        PKG_MANAGER="yum"
    fi
    PYTHON_DEPS=(
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
    )
else
    print_error "Unknown package manager - cannot check dependencies"
    exit 2
fi

PYTHON_MISSING=()
for dep in "${PYTHON_DEPS[@]}"; do
    if eval $PKG_CHECK_CMD; then
        print_success "$dep"
    else
        print_error "$dep (missing)"
        PYTHON_MISSING+=("$dep")
    fi
done

if [ ${#PYTHON_MISSING[@]} -gt 0 ]; then
    MISSING_DEPS+=("${PYTHON_MISSING[@]}")
fi

# Check for existing Python 3.11 installation
print_header "Existing Installations"
MACE_PYTHON_DIR="$HOME/mace_python"
if [ -d "$MACE_PYTHON_DIR" ]; then
    print_warning "Found existing $MACE_PYTHON_DIR - will be used if valid"
    SYSTEM_INFO+=("existing_python:$MACE_PYTHON_DIR")

    if [ -x "$MACE_PYTHON_DIR/bin/python3" ]; then
        EXISTING_PY_VER=$($MACE_PYTHON_DIR/bin/python3 --version 2>&1 | awk '{print $2}')
        print_success "Existing Python: $EXISTING_PY_VER"
        SYSTEM_INFO+=("existing_python_version:$EXISTING_PY_VER")
    fi
else
    print_success "No existing installation - clean install"
    SYSTEM_INFO+=("existing_python:None")
fi

# Generate summary
print_header "Summary"

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    print_error "Missing ${#MISSING_DEPS[@]} dependencies"
    if [ "$JSON_OUTPUT" = false ]; then
        echo ""
        echo "Install command:"
        if [ "$PKG_MANAGER" = "apt-get" ]; then
            echo "  sudo apt-get update && sudo apt-get install -y \\"
        elif [ "$PKG_MANAGER" = "dnf" ]; then
            echo "  sudo dnf install -y \\"
        elif [ "$PKG_MANAGER" = "yum" ]; then
            echo "  sudo yum install -y \\"
        fi
        for dep in "${MISSING_DEPS[@]}"; do
            echo "    $dep \\"
        done | sed '$ s/ \\$//'
        echo ""
    fi
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    print_warning "${#WARNINGS[@]} warnings"
    if [ "$JSON_OUTPUT" = false ]; then
        for warn in "${WARNINGS[@]}"; do
            echo "  - ${warn#*:}"
        done
    fi
fi

# JSON output
if [ "$JSON_OUTPUT" = true ]; then
    echo "{"
    echo "  \"system\": {"
    for info in "${SYSTEM_INFO[@]}"; do
        key="${info%%:*}"
        value="${info#*:}"
        echo "    \"$key\": \"$value\","
    done | sed '$ s/,$//'
    echo "  },"
    echo "  \"missing_dependencies\": ["
    for dep in "${MISSING_DEPS[@]}"; do
        echo "    \"$dep\","
    done | sed '$ s/,$//'
    echo "  ],"
    echo "  \"warnings\": ["
    for warn in "${WARNINGS[@]}"; do
        echo "    \"${warn}\","
    done | sed '$ s/,$//'
    echo "  ]"
    echo "}"
else
    echo ""
    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        print_success "All requirements met!"
        echo ""
        echo "Ready to run: ./install_mace_wrapper.sh"
    else
        print_error "Please install missing dependencies first"
        exit 1
    fi
fi
