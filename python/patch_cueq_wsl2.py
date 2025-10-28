"""
Patch cuEquivariance to work in WSL2 environment
WSL2 doesn't support several NVML calls needed by cuEquivariance
"""
import pynvml

# Save original functions
original_get_power_limit = pynvml.nvmlDeviceGetPowerManagementLimit
original_get_num_gpu_cores = pynvml.nvmlDeviceGetNumGpuCores

def patched_get_power_limit(handle):
    """Return a default power limit instead of querying (not supported in WSL2)"""
    try:
        return original_get_power_limit(handle)
    except pynvml.NVMLError_NotSupported:
        # Return a reasonable default for RTX 3070 Laptop (125W)
        return 125000  # milliwatts

def patched_get_num_gpu_cores(handle):
    """Return default GPU core count (not supported in WSL2)"""
    try:
        return original_get_num_gpu_cores(handle)
    except pynvml.NVMLError_NotSupported:
        # RTX 3070 has 5888 CUDA cores
        return 5888

# Apply patches
pynvml.nvmlDeviceGetPowerManagementLimit = patched_get_power_limit
pynvml.nvmlDeviceGetNumGpuCores = patched_get_num_gpu_cores

print("✓ WSL2 patch applied for cuEquivariance")
