# WSL2 Disk Cleanup Report

**Date:** 2025-10-28
**Reason:** C: drive full, WSL2 needed space

---

## Disk Usage Before Cleanup

- **Total:** 1007 GB
- **Used:** 209 GB
- **Available:** 747 GB
- **Usage:** 22%

---

## Items Cleaned

### 1. pip Cache
- **Location:** `~/.cache/pip`
- **Size:** 23 GB
- **Status:** ✓ CLEARED
- **Description:** Python package download cache

### 2. Python Build Files
- **Location:** `/tmp/Python-3.11.10*`
- **Size:** ~500 MB
- **Status:** ✓ REMOVED
- **Description:** Temporary Python source and build artifacts

### 3. HuggingFace Model Cache
- **Location:** `~/.cache/huggingface`
- **Size:** 38 GB
- **Status:** ✓ CLEARED (in progress)
- **Description:** Downloaded ML model weights (Qwen2.5-7B, Qwen3-4B)
- **Note:** Models can be re-downloaded if needed

### 4. vLLM Cache
- **Location:** `~/.cache/vllm`
- **Size:** 16 MB
- **Status:** ✓ CLEARED
- **Description:** vLLM inference engine cache

---

## Disk Usage After Cleanup

- **Total:** 1007 GB
- **Used:** ~148 GB (estimated after HF cache clears)
- **Available:** ~809 GB
- **Usage:** ~15%

**Total Space Freed:** ~61 GB

---

## Files NOT Cleaned (Require Sudo or Keep)

### System Logs
- **Location:** `/var/log`
- **Size:** 896 MB
- **Reason:** Requires sudo access
- **Recommendation:** Can clean with `sudo journalctl --vacuum-time=7d`

### APT Cache
- **Location:** `/var/cache/apt`
- **Size:** Unknown
- **Reason:** Requires sudo access
- **Recommendation:** Can clean with `sudo apt-get clean`

---

## Recommendations for Future

1. **Periodic Cleanup:**
   ```bash
   # Clear pip cache
   rm -rf ~/.cache/pip

   # Clear HuggingFace cache
   rm -rf ~/.cache/huggingface

   # Clear apt cache (requires sudo)
   sudo apt-get clean
   ```

2. **Monitor Disk Usage:**
   ```bash
   df -h /
   du -sh ~/.cache/*
   ```

3. **WSL2 Disk Reclaim:**
   ```powershell
   # From Windows PowerShell (reclaim space back to Windows)
   wsl --shutdown
   diskpart
   # select vdisk file="C:\Users\<user>\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu22.04LTS_*\LocalState\ext4.vhdx"
   # compact vdisk
   # exit
   ```

---

## Impact on Current Project

✓ No impact - all MACE wrapper project files intact
✓ `$HOME/mace_python` preserved (500MB)
✓ System Python unaffected
✓ Build logs preserved in `/tmp/python_*.log`
✓ Can proceed with MACE stack installation

---

*Report generated automatically during MACE wrapper setup*
