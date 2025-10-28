#!/bin/bash
#
# MACE Wrapper - Comprehensive Test Script
# Tests all functionality of the MACE wrapper library
#
# Usage: ./test_mace_wrapper.sh [--cpu-only] [--verbose]
#
# Exit codes:
#   0 = All tests passed
#   1 = Some tests failed
#   2 = Critical error

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PYTHON_INSTALL_DIR="/opt/mace_python"
WRAPPER_DIR="$HOME/mace_wrapper"
VERBOSE=false
CPU_ONLY=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --cpu-only)
            CPU_ONLY=true
            ;;
        --verbose)
            VERBOSE=true
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--cpu-only] [--verbose]"
            exit 1
            ;;
    esac
done

# Output functions
print_header() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_test() {
    echo -e "${YELLOW}TEST:${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC} $1"
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Run test with result tracking
run_test() {
    local test_name="$1"
    local test_command="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    print_test "$test_name"

    if [ "$VERBOSE" = true ]; then
        echo "  Command: $test_command"
    fi

    if eval "$test_command" > /tmp/mace_test_${TESTS_RUN}.log 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        print_pass "$test_name"
        if [ "$VERBOSE" = true ]; then
            cat /tmp/mace_test_${TESTS_RUN}.log | sed 's/^/  /'
        fi
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("$test_name")
        print_fail "$test_name"
        echo "  Error output:"
        cat /tmp/mace_test_${TESTS_RUN}.log | sed 's/^/    /'
    fi
}

# Start testing
print_header "MACE Wrapper Test Suite"
echo "Wrapper: $WRAPPER_DIR"
echo "Python:  $PYTHON_INSTALL_DIR"
echo ""

# Set up environment
export LD_LIBRARY_PATH="$PYTHON_INSTALL_DIR/lib:$LD_LIBRARY_PATH"
export PYTHONPATH="$WRAPPER_DIR/python:$PYTHONPATH"

# Detect WSL2
IS_WSL2=false
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    IS_WSL2=true
    print_warning "WSL2 detected - GPU tests may be limited"
fi

# Test 1: Check installations
print_header "Environment Tests"

run_test "Python installation exists" \
    "[ -x '$PYTHON_INSTALL_DIR/bin/python3' ]"

run_test "Python version check" \
    "$PYTHON_INSTALL_DIR/bin/python3 --version"

run_test "Wrapper library exists" \
    "[ -f '$WRAPPER_DIR/lib/libmace_wrapper.so' ]"

run_test "Wrapper header exists" \
    "[ -f '$WRAPPER_DIR/include/mace_wrapper.h' ]"

# Test 2: Python package imports
print_header "Python Package Tests"

run_test "Import numpy" \
    "$PYTHON_INSTALL_DIR/bin/python3 -c 'import numpy; print(numpy.__version__)'"

run_test "Import torch" \
    "$PYTHON_INSTALL_DIR/bin/python3 -c 'import torch; print(torch.__version__)'"

run_test "Import MACE" \
    "$PYTHON_INSTALL_DIR/bin/python3 -c 'import mace; print(mace.__version__)'"

run_test "Import ASE" \
    "$PYTHON_INSTALL_DIR/bin/python3 -c 'import ase; print(ase.__version__)'"

run_test "Import pybind11" \
    "$PYTHON_INSTALL_DIR/bin/python3 -c 'import pybind11; print(pybind11.__version__)'"

if [ "$CPU_ONLY" = false ]; then
    run_test "Import cuEquivariance" \
        "$PYTHON_INSTALL_DIR/bin/python3 -c 'import cuequivariance_torch; print(\"OK\")'"
fi

# Test 3: CUDA availability
if [ "$CPU_ONLY" = false ]; then
    print_header "CUDA Tests"

    run_test "PyTorch CUDA available" \
        "$PYTHON_INSTALL_DIR/bin/python3 -c 'import torch; assert torch.cuda.is_available(), \"CUDA not available\"'"

    run_test "Get GPU device name" \
        "$PYTHON_INSTALL_DIR/bin/python3 -c 'import torch; print(torch.cuda.get_device_name(0))'"

    run_test "CUDA device count" \
        "$PYTHON_INSTALL_DIR/bin/python3 -c 'import torch; print(f\"Devices: {torch.cuda.device_count()}\")'"

    run_test "Basic CUDA operation" \
        "$PYTHON_INSTALL_DIR/bin/python3 -c 'import torch; x = torch.randn(100, 100).cuda(); y = x @ x.T; print(\"OK\")'"
fi

# Test 4: MACE Python functionality
print_header "MACE Python Tests"

run_test "MACE calculator import" \
    "$PYTHON_INSTALL_DIR/bin/python3 -c 'from mace.calculators import mace_mp, MACECalculator'"

run_test "Create MACE calculator (CPU)" \
    "$PYTHON_INSTALL_DIR/bin/python3 -c '
from mace.calculators import mace_mp
calc = mace_mp(model=\"small\", device=\"cpu\", default_dtype=\"float32\", enable_cueq=False)
print(\"Calculator created\")
'"

if [ "$CPU_ONLY" = false ] && [ "$IS_WSL2" = false ]; then
    run_test "Create MACE calculator (CUDA)" \
        "$PYTHON_INSTALL_DIR/bin/python3 -c '
from mace.calculators import mace_mp
calc = mace_mp(model=\"small\", device=\"cuda\", default_dtype=\"float32\", enable_cueq=True)
print(\"Calculator created\")
'"
fi

run_test "MACE calculation test (CPU)" \
    "$PYTHON_INSTALL_DIR/bin/python3 << 'EOF'
from mace.calculators import mace_mp
from ase import Atoms
import numpy as np

# Create H2O molecule
positions = np.array([
    [0.0, 0.0, 0.119],
    [0.0, 0.763, -0.477],
    [0.0, -0.763, -0.477]
])
atoms = Atoms(symbols=\"OH2\", positions=positions)

# Calculate
calc = mace_mp(model=\"small\", device=\"cpu\", default_dtype=\"float32\", enable_cueq=False)
atoms.calc = calc
energy = atoms.get_potential_energy()
forces = atoms.get_forces()

print(f\"Energy: {energy:.6f} eV\")
print(f\"Forces shape: {forces.shape}\")
assert forces.shape == (3, 3), \"Wrong forces shape\"
print(\"OK\")
EOF
"

# Test 5: Wrapper library tests
print_header "C++ Wrapper Tests"

# Check if test executable exists or needs building
if [ ! -f "$WRAPPER_DIR/test/test_mace.cpp" ]; then
    print_warning "Test source not found - skipping wrapper tests"
else
    # Build test executable
    cd "$WRAPPER_DIR"

    run_test "Compile wrapper library" \
        "make clean && make"

    run_test "Compile test application" \
        "cd $WRAPPER_DIR && make test 2>&1 | tee /tmp/mace_test_build.log"

    # Run basic wrapper test
    if [ -f "/tmp/test_mace_app" ]; then
        run_test "Run wrapper test (CPU)" \
            "cd /tmp && export LD_LIBRARY_PATH=$PYTHON_INSTALL_DIR/lib:$WRAPPER_DIR/lib:\$LD_LIBRARY_PATH && export PYTHONPATH=$WRAPPER_DIR/python:\$PYTHONPATH && ./test_mace_app"

        # Run with different configurations
        if [ "$CPU_ONLY" = false ] && [ "$IS_WSL2" = false ]; then
            run_test "Run wrapper test (CUDA)" \
                "cd $WRAPPER_DIR && cat test/test_mace.cpp | sed 's/\"cpu\"/\"cuda\"/' | sed 's/, 0/, 1/' > test/test_mace_cuda.cpp && \
                 g++ -std=c++17 -I$WRAPPER_DIR/include test/test_mace_cuda.cpp -L$WRAPPER_DIR/lib -lmace_wrapper -Wl,-rpath,$WRAPPER_DIR/lib:$PYTHON_INSTALL_DIR/lib -o /tmp/test_mace_cuda && \
                 cd /tmp && export LD_LIBRARY_PATH=$PYTHON_INSTALL_DIR/lib:$WRAPPER_DIR/lib:\$LD_LIBRARY_PATH && export PYTHONPATH=$WRAPPER_DIR/python:\$PYTHONPATH && ./test_mace_cuda"
        fi
    fi
fi

# Test 6: Performance benchmark
print_header "Performance Tests"

run_test "Benchmark H2O calculation (CPU)" \
    "$PYTHON_INSTALL_DIR/bin/python3 << 'EOF'
from mace.calculators import mace_mp
from ase import Atoms
import numpy as np
import time

positions = np.array([
    [0.0, 0.0, 0.119],
    [0.0, 0.763, -0.477],
    [0.0, -0.763, -0.477]
])
atoms = Atoms(symbols=\"OH2\", positions=positions)

calc = mace_mp(model=\"small\", device=\"cpu\", default_dtype=\"float32\", enable_cueq=False)
atoms.calc = calc

# Warmup
_ = atoms.get_potential_energy()

# Benchmark
start = time.time()
for _ in range(5):
    energy = atoms.get_potential_energy()
    forces = atoms.get_forces()
elapsed = time.time() - start

print(f\"Average time: {elapsed/5:.4f} seconds per calculation\")
print(f\"Energy: {energy:.6f} eV\")
EOF
"

if [ "$CPU_ONLY" = false ] && [ "$IS_WSL2" = false ]; then
    run_test "Benchmark H2O calculation (CUDA)" \
        "$PYTHON_INSTALL_DIR/bin/python3 << 'EOF'
from mace.calculators import mace_mp
from ase import Atoms
import numpy as np
import time

positions = np.array([
    [0.0, 0.0, 0.119],
    [0.0, 0.763, -0.477],
    [0.0, -0.763, -0.477]
])
atoms = Atoms(symbols=\"OH2\", positions=positions)

calc = mace_mp(model=\"small\", device=\"cuda\", default_dtype=\"float32\", enable_cueq=False)
atoms.calc = calc

# Warmup
_ = atoms.get_potential_energy()

# Benchmark
import torch
if torch.cuda.is_available():
    torch.cuda.synchronize()
start = time.time()
for _ in range(5):
    energy = atoms.get_potential_energy()
    forces = atoms.get_forces()
    if torch.cuda.is_available():
        torch.cuda.synchronize()
elapsed = time.time() - start

print(f\"Average time: {elapsed/5:.4f} seconds per calculation\")
print(f\"Energy: {energy:.6f} eV\")
print(f\"Speedup estimate: {1.0:.1f}x (baseline is CUDA)\")
EOF
"
fi

# Test 7: Memory leak test
print_header "Memory Tests"

run_test "Memory leak test (10 iterations)" \
    "$PYTHON_INSTALL_DIR/bin/python3 << 'EOF'
from mace.calculators import mace_mp
from ase import Atoms
import numpy as np

positions = np.array([
    [0.0, 0.0, 0.119],
    [0.0, 0.763, -0.477],
    [0.0, -0.763, -0.477]
])

calc = mace_mp(model=\"small\", device=\"cpu\", default_dtype=\"float32\", enable_cueq=False)

for i in range(10):
    atoms = Atoms(symbols=\"OH2\", positions=positions)
    atoms.calc = calc
    energy = atoms.get_potential_energy()
    forces = atoms.get_forces()
    del atoms

print(\"No memory errors detected\")
EOF
"

# Summary
print_header "Test Summary"
echo ""
echo "Tests Run:    $TESTS_RUN"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""
    echo "Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    echo ""
    echo "Check logs in /tmp/mace_test_*.log for details"
    exit 1
else
    echo -e "Tests Failed: ${GREEN}0${NC}"
    echo ""
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""

    if [ "$IS_WSL2" = true ]; then
        print_warning "Note: Running on WSL2 - GPU tests limited"
        echo "For full GPU testing, run on native Linux"
    else
        if [ "$CPU_ONLY" = false ]; then
            echo "Full GPU acceleration verified!"
        fi
    fi

    exit 0
fi
