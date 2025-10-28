"""Debug import issues"""
import sys
print("=== Python sys.path ===")
for p in sys.path:
    print(f"  {p}")

print("\n=== Attempting imports ===")
try:
    import numpy
    print(f"✓ numpy: {numpy.__file__}")
except Exception as e:
    print(f"✗ numpy: {e}")

try:
    import mace
    print(f"✓ mace: {mace.__file__}")
except Exception as e:
    print(f"✗ mace: {e}")
