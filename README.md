# MACE Wrapper

C++ wrapper for MACE (Multi-Atomic Cluster Expansion) machine learning potentials with embedded Python interpreter.

## Overview

This project provides a C++ shared library that wraps MACE machine learning potentials, enabling their use in C++ applications without requiring external Python processes. It uses pybind11 to embed a Python interpreter and provides a clean C API for molecular dynamics calculations.

## Key Features

- **Isolated Python Environment**: Installs Python 3.11.10 to `$HOME/mace_python` (no sudo required)
- **Self-Contained**: All dependencies (PyTorch, MACE, cuEquivariance) installed in user directory
- **C++ API**: Simple C interface for energy and force calculations
- **GPU Acceleration**: Full CUDA support with cuEquivariance on native Linux
- **Multi-Platform**: Supports Ubuntu 20.04+ and RHEL 8+ / Rocky Linux 8+
- **WSL2 Compatible**: Automatic patching for WSL2 environments

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/rk27599/mace_wrapper.git
cd mace_wrapper

# 2. Check system requirements
cd scripts
chmod +x *.sh
./detect_env.sh

# 3. Install dependencies (Ubuntu example)
sudo apt-get update && sudo apt-get install -y \
    build-essential libncurses5-dev libreadline-dev libsqlite3-dev \
    libgdbm-dev libdb-dev libbz2-dev liblzma-dev uuid-dev \
    libffi-dev libssl-dev zlib1g-dev wget ca-certificates

# For RHEL/Rocky Linux:
# sudo dnf install -y gcc gcc-c++ make ncurses-devel readline-devel \
#     sqlite-devel gdbm-devel libdb-devel bzip2-devel xz-devel \
#     libuuid-devel libffi-devel openssl-devel zlib-devel wget ca-certificates

# 4. Run automated installation
./install_mace_wrapper.sh

# 5. Test installation
./test_mace_wrapper.sh
```

## Installation Details

The installation creates:

- **`$HOME/mace_python/`** - Isolated Python 3.11.10 installation (~6GB)
  - PyTorch with CUDA support
  - MACE machine learning potentials
  - cuEquivariance for GPU acceleration
  - All pip packages in user directory

- **`$HOME/mace_wrapper/`** - Wrapper library and source code
  - `lib/libmace_wrapper_v1.so` - Shared library
  - `include/mace_wrapper.h` - C API header
  - `python/mace_calculator.py` - Python calculator implementation

**Total disk space required:** ~6GB
**No sudo required** for Python installation (only for system packages)

## System Requirements

### Minimum
- **OS:** Ubuntu 20.04+ / RHEL 8+ / Rocky Linux 8+
- **CPU:** Any modern x86_64 processor
- **RAM:** 8GB
- **Disk:** 15GB free space
- **Build Tools:** GCC 7+, Make 4+

### Recommended
- **OS:** Ubuntu 22.04 LTS / RHEL 8+ (native, not WSL2)
- **CPU:** 8+ cores for faster builds
- **RAM:** 16GB+
- **GPU:** NVIDIA GPU with 8GB+ VRAM
- **CUDA:** 11.8 or 12.x

## Usage Example

```cpp
#include "mace_wrapper.h"

int main() {
    // Initialize MACE calculator
    void* calc = mace_calculator_create(
        "medium",           // model size
        "cuda",             // device
        1                   // enable cuEquivariance
    );

    // Calculate energy and forces
    double positions[] = {0.0, 0.0, 0.0, 0.96, 0.0, 0.0, /* ... */};
    int atomic_numbers[] = {8, 1, 1};
    double cell[] = {10.0, 0, 0, 0, 10.0, 0, 0, 0, 10.0};

    double energy, forces[9];
    mace_calculator_calculate(
        calc, positions, atomic_numbers, 3,
        cell, 1, &energy, forces
    );

    printf("Energy: %.6f eV\n", energy);

    // Cleanup
    mace_calculator_destroy(calc);
    return 0;
}
```

## Project Structure

```
mace_wrapper/
├── scripts/              # Automation scripts
│   ├── detect_env.sh           # Environment detection
│   ├── install_mace_wrapper.sh # Full installation
│   ├── test_mace_wrapper.sh    # Test suite
│   ├── run_mace_app.sh         # Run wrapper application
│   ├── package_mace_wrapper.sh # Create deployment package
│   └── README.md               # Detailed script documentation
├── src/
│   └── mace_wrapper.cpp  # C++ wrapper implementation
├── include/
│   └── mace_wrapper.h    # C API header
├── python/
│   └── mace_calculator.py # Python calculator wrapper
├── test/
│   └── test_mace.cpp     # Test application
├── env.sh                # Environment setup helper
├── Makefile              # Build configuration
└── README.md             # This file
```

## Scripts

- **`detect_env.sh`** - Detects system capabilities and checks dependencies
- **`install_mace_wrapper.sh`** - Automated full installation (~30 minutes)
- **`test_mace_wrapper.sh`** - Comprehensive test suite
- **`run_mace_app.sh`** - Execute wrapper with proper environment
- **`package_mace_wrapper.sh`** - Create deployment tarball

See [scripts/README.md](scripts/README.md) for detailed documentation.

## Environment Setup

After installation, you need to set up the environment to use the isolated Python:

```bash
# Option 1: Source the environment helper (recommended)
source env.sh

# Option 2: Set manually
export LD_LIBRARY_PATH=$HOME/mace_python/lib:$LD_LIBRARY_PATH
export PATH=$HOME/mace_python/bin:$PATH
```

**Note:** The wrapper library has RPATH configured and works without setting `LD_LIBRARY_PATH`. However, to run Python directly or use pip, you need to set the library path as shown above.

## Building

```bash
# Build wrapper library
make

# View build configuration
make info

# Run tests
make test

# Clean build artifacts
make clean
```

## WSL2 Compatibility

When running on WSL2, the installer automatically:
- Detects WSL2 environment
- Applies compatibility patch to cuEquivariance
- Works in CPU mode with full functionality
- GPU acceleration limited (Triton kernels not supported)

For full GPU acceleration, use native Linux.

## Documentation

- [Scripts Documentation](scripts/README.md) - Detailed automation guide
- [Installation Report](AUTOMATION_COMPLETE.md) - Complete installation details
- [Project Status](PROJECT_STATUS_SUMMARY.md) - Current project status

## License

This project wraps and uses:
- [MACE](https://github.com/ACEsuit/mace) - Machine learning force fields
- [PyTorch](https://pytorch.org/) - Deep learning framework
- [pybind11](https://github.com/pybind/pybind11) - C++/Python bindings
- [cuEquivariance](https://github.com/Linux-cpp-lisp/cuequivariance) - GPU acceleration

## Contributing

Contributions are welcome! This wrapper was designed for:
- Embedding MACE in C++ applications
- High-performance molecular dynamics
- Production deployments requiring isolated Python

## Author

Created as part of MACE integration work for C++ applications.
