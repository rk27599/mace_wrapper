#include "../include/mace_wrapper.h"
#include <stdio.h>
#include <stdlib.h>

int main() {
    printf("=== MACE Wrapper Test ===\n\n");

    /* Initialize MACE */
    printf("Initializing MACE calculator...\n");
    printf("Using 'small' model with GPU acceleration (CUDA + cuEquivariance)...\n");
    printf("WSL2 patch applied - cuEquivariance enabled for 3-10x speedup!\n");
    MACEHandle mace = mace_init(NULL, "small", "cuda", 1);

    if (!mace) {
        fprintf(stderr, "Failed to initialize MACE\n");
        return 1;
    }
    printf("✓ MACE initialized successfully\n\n");

    /* Test 1: Water molecule */
    printf("--- Test 1: H2O Molecule ---\n");
    double positions[] = {
        0.0, 0.0, 0.119,
        0.0, 0.763, -0.477,
        0.0, -0.763, -0.477
    };

    int atomic_numbers[] = {8, 1, 1};
    int num_atoms = 3;

    MACEResult result;
    mace_calculate(mace, positions, atomic_numbers, num_atoms, &result);

    if (result.success) {
        printf("Energy: %.6f eV\n", result.energy);
        printf("Forces:\n");
        for (int i = 0; i < num_atoms; i++) {
            printf("  Atom %d: [%8.6f, %8.6f, %8.6f] eV/Å\n", i,
                   result.forces[i*3 + 0],
                   result.forces[i*3 + 1],
                   result.forces[i*3 + 2]);
        }
        mace_free_result(&result);
    } else {
        fprintf(stderr, "Calculation failed: %s\n", result.error_msg);
        return 1;
    }

    printf("\n✓ Test passed!\n");

    /* Cleanup */
    mace_destroy(mace);
    printf("\n=== All tests completed successfully ===\n");

    return 0;
}
