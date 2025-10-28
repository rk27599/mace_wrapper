#!/bin/bash
#
# MACE Wrapper Environment Setup
#
# Usage: source env.sh
#
# This script sets up the environment to use the isolated Python installation
# and MACE wrapper library.

# Set Python library path
export LD_LIBRARY_PATH="$HOME/mace_python/lib:$LD_LIBRARY_PATH"

# Add Python binaries to PATH
export PATH="$HOME/mace_python/bin:$PATH"

# Add MACE wrapper Python module to PYTHONPATH
export PYTHONPATH="$HOME/mace_wrapper/python:$PYTHONPATH"

echo "MACE Wrapper environment configured:"
echo "  Python: $HOME/mace_python/bin/python3"
echo "  Library path: $HOME/mace_python/lib"
echo "  Wrapper: $HOME/mace_wrapper"
echo ""
echo "You can now:"
echo "  - Run Python: python3"
echo "  - Use MACE: python3 -c 'import mace; print(mace.__version__)'"
echo "  - Build wrapper: cd ~/mace_wrapper && make"
