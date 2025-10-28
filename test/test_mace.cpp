#include "../include/mace_wrapper.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Check if running in WSL2
int is_wsl2() {
    FILE *fp = fopen("/proc/version", "r");
    if (!fp) return 0;

    char buffer[256];
    int is_wsl = 0;
    if (fgets(buffer, sizeof(buffer), fp) != NULL) {
        if (strstr(buffer, "Microsoft") || strstr(buffer, "WSL")) {
            is_wsl = 1;
        }
    }
    fclose(fp);
    return is_wsl;
}

int main() {
    printf("=== MACE Wrapper Test ===\n\n");

    /* Detect environment */
    int wsl2 = is_wsl2();
    const char *device = wsl2 ? "cpu" : "cuda";
    int enable_cueq = wsl2 ? 0 : 1;

    /* Initialize MACE */
    printf("Initializing MACE calculator...\n");
    if (wsl2) {
        printf("WSL2 detected - using CPU mode (cuEquivariance not compatible with WSL2)\n");
    } else {
        printf("Using 'small' model with GPU acceleration (CUDA + cuEquivariance)...\n");
    }

    MACEHandle mace = mace_init(NULL, "small", device, enable_cueq);

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
