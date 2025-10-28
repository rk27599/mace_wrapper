"""MACE calculator module for C API"""
import numpy as np

# Apply WSL2 patch for cuEquivariance before importing MACE
try:
    import patch_cueq_wsl2
except ImportError:
    pass  # Patch not needed on non-WSL2 systems

from mace.calculators import mace_mp, MACECalculator
from ase import Atoms

_calculator = None

def initialize_mace(model_path=None, model_type="medium", device="cuda",
                   enable_cueq=True, dtype="float32"):
    """Initialize global MACE calculator"""
    global _calculator

    try:
        if model_path is not None:
            _calculator = MACECalculator(
                model_paths=model_path,
                device=device,
                default_dtype=dtype,
                enable_cueq=enable_cueq
            )
        else:
            _calculator = mace_mp(
                model=model_type,
                device=device,
                default_dtype=dtype,
                enable_cueq=enable_cueq
            )
        return True
    except Exception as e:
        print(f"MACE initialization failed: {e}")
        return False

def compute_energy_forces(positions, atomic_numbers, cell=None, pbc=None):
    """Compute energy and forces"""
    if _calculator is None:
        raise RuntimeError("MACE not initialized")

    positions = np.array(positions, dtype=np.float64)
    atomic_numbers = np.array(atomic_numbers, dtype=np.int32)

    atoms = Atoms(
        numbers=atomic_numbers,
        positions=positions,
        cell=cell,
        pbc=pbc if pbc is not None else [False, False, False]
    )

    atoms.calc = _calculator

    energy = atoms.get_potential_energy()
    forces = atoms.get_forces()

    return {
        'energy': float(energy),
        'forces': forces.tolist()
    }
