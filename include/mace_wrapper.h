#ifndef MACE_WRAPPER_H
#define MACE_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque handle to MACE calculator */
typedef void* MACEHandle;

/* Result structure for energy/forces calculations */
typedef struct {
    double energy;                  /* Total energy in eV */
    double* forces;                 /* Forces array [fx0,fy0,fz0,fx1,...] eV/Å */
    int num_atoms;                  /* Number of atoms */
    int success;                    /* 1=success, 0=failure */
    char error_msg[512];            /* Error message if failed */
} MACEResult;

/**
 * Initialize MACE calculator
 * @param model_path: Path to MACE model file (NULL for pretrained)
 * @param model_type: "small", "medium", or "large" (for pretrained)
 * @param device: "cuda" or "cpu"
 * @param enable_cueq: 1 to enable cuEquivariance, 0 to disable
 * @return: Handle to MACE calculator, NULL on failure
 */
MACEHandle mace_init(const char* model_path,
                     const char* model_type,
                     const char* device,
                     int enable_cueq);

/**
 * Calculate energy and forces for atomic configuration
 * @param handle: MACE calculator handle
 * @param positions: Atomic positions [x0,y0,z0,x1,y1,z1,...] in Angstroms
 * @param atomic_numbers: Atomic numbers [Z0,Z1,Z2,...]
 * @param num_atoms: Number of atoms
 * @param result: Output result structure (caller allocates)
 */
void mace_calculate(MACEHandle handle,
                    const double* positions,
                    const int* atomic_numbers,
                    int num_atoms,
                    MACEResult* result);

/**
 * Calculate with periodic boundary conditions
 * @param cell: 3x3 cell matrix [a_x,a_y,a_z,b_x,b_y,b_z,c_x,c_y,c_z]
 * @param pbc: Periodic boundary [x, y, z] (each 0 or 1)
 */
void mace_calculate_periodic(MACEHandle handle,
                             const double* positions,
                             const int* atomic_numbers,
                             int num_atoms,
                             const double* cell,
                             const int* pbc,
                             MACEResult* result);

/* Free forces array */
void mace_free_forces(double* forces);

/* Free result structure */
void mace_free_result(MACEResult* result);

/* Destroy calculator */
void mace_destroy(MACEHandle handle);

/* Get error message */
const char* mace_get_error(MACEHandle handle);

#ifdef __cplusplus
}
#endif

#endif /* MACE_WRAPPER_H */
