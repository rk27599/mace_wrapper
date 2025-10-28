#include "mace_wrapper.h"
#include <pybind11/embed.h>
#include <pybind11/stl.h>
#include <dlfcn.h>
#include <string>
#include <cstring>
#include <iostream>
#include <cstdlib>

namespace py = pybind11;

struct MACECalculator {
    py::scoped_interpreter* interpreter;
    py::module_* mace_module;
    std::string last_error;
};

static py::scoped_interpreter* g_interpreter = nullptr;
static int g_init_count = 0;

extern "C" {

MACEHandle mace_init(const char* model_path,
                     const char* model_type,
                     const char* device,
                     int enable_cueq)
{
    try {
        MACECalculator* calc = new MACECalculator();

        if (g_init_count == 0) {
            // Set PYTHONHOME to isolated Python installation
            setenv("PYTHONHOME", "/opt/mace_python", 1);

            g_interpreter = new py::scoped_interpreter();

            py::module_ sys = py::module_::import("sys");
            py::list path = sys.attr("path");

            // Remove current working directory (can cause import conflicts)
            try {
                path.attr("remove")(".");
            } catch (...) {}
            try {
                path.attr("remove")("");
            } catch (...) {}

            // Add MACE wrapper Python module paths
            Dl_info dl_info;
            if (dladdr((void*)mace_init, &dl_info)) {
                std::string so_dir = dl_info.dli_fname;
                size_t last_slash = so_dir.find_last_of('/');
                if (last_slash != std::string::npos) {
                    so_dir = so_dir.substr(0, last_slash);
                    path.insert(0, (so_dir + "/../python").c_str());
                }
            }
        }
        g_init_count++;

        calc->interpreter = g_interpreter;
        calc->mace_module = new py::module_(py::module_::import("mace_calculator"));

        py::object init_func = calc->mace_module->attr("initialize_mace");

        py::object py_model_path;
        if (model_path) {
            py_model_path = py::str(model_path);
        } else {
            py_model_path = py::none();
        }

        py::object result = init_func(
            py_model_path,
            py::str(model_type ? model_type : "medium"),
            py::str(device ? device : "cuda"),
            py::bool_(enable_cueq),
            py::str("float32")
        );

        if (!result.cast<bool>()) {
            delete calc;
            calc->last_error = "Failed to initialize MACE calculator";
            return nullptr;
        }

        return static_cast<MACEHandle>(calc);

    } catch (const std::exception& e) {
        std::cerr << "MACE init error: " << e.what() << std::endl;
        return nullptr;
    }
}

void mace_calculate(MACEHandle handle,
                    const double* positions,
                    const int* atomic_numbers,
                    int num_atoms,
                    MACEResult* result)
{
    if (!handle || !result) {
        if (result) {
            result->success = 0;
            strncpy(result->error_msg, "Invalid handle or result pointer",
                   sizeof(result->error_msg) - 1);
        }
        return;
    }

    MACECalculator* calc = static_cast<MACECalculator*>(handle);

    try {
        py::list py_positions;
        for (int i = 0; i < num_atoms; ++i) {
            py::list pos;
            pos.append(positions[i*3 + 0]);
            pos.append(positions[i*3 + 1]);
            pos.append(positions[i*3 + 2]);
            py_positions.append(pos);
        }

        py::list py_atomic_numbers;
        for (int i = 0; i < num_atoms; ++i) {
            py_atomic_numbers.append(atomic_numbers[i]);
        }

        py::object compute_func = calc->mace_module->attr("compute_energy_forces");
        py::dict py_result = compute_func(py_positions, py_atomic_numbers,
                                          py::none(), py::none());

        result->energy = py_result["energy"].cast<double>();
        result->num_atoms = num_atoms;
        result->success = 1;
        result->error_msg[0] = '\0';

        result->forces = new double[num_atoms * 3];
        py::list forces_list = py_result["forces"];
        for (int i = 0; i < num_atoms; ++i) {
            py::list force = forces_list[i];
            result->forces[i*3 + 0] = force[0].cast<double>();
            result->forces[i*3 + 1] = force[1].cast<double>();
            result->forces[i*3 + 2] = force[2].cast<double>();
        }

    } catch (const std::exception& e) {
        result->success = 0;
        strncpy(result->error_msg, e.what(), sizeof(result->error_msg) - 1);
        calc->last_error = e.what();
    }
}

void mace_calculate_periodic(MACEHandle handle,
                             const double* positions,
                             const int* atomic_numbers,
                             int num_atoms,
                             const double* cell,
                             const int* pbc,
                             MACEResult* result)
{
    if (!handle || !result) {
        if (result) {
            result->success = 0;
            strncpy(result->error_msg, "Invalid handle", sizeof(result->error_msg) - 1);
        }
        return;
    }

    MACECalculator* calc = static_cast<MACECalculator*>(handle);

    try {
        py::list py_positions;
        for (int i = 0; i < num_atoms; ++i) {
            py::list pos;
            pos.append(positions[i*3 + 0]);
            pos.append(positions[i*3 + 1]);
            pos.append(positions[i*3 + 2]);
            py_positions.append(pos);
        }

        py::list py_atomic_numbers;
        for (int i = 0; i < num_atoms; ++i) {
            py_atomic_numbers.append(atomic_numbers[i]);
        }

        py::list py_cell;
        for (int i = 0; i < 3; ++i) {
            py::list row;
            row.append(cell[i*3 + 0]);
            row.append(cell[i*3 + 1]);
            row.append(cell[i*3 + 2]);
            py_cell.append(row);
        }

        py::list py_pbc;
        py_pbc.append(py::bool_(pbc[0]));
        py_pbc.append(py::bool_(pbc[1]));
        py_pbc.append(py::bool_(pbc[2]));

        py::object compute_func = calc->mace_module->attr("compute_energy_forces");
        py::dict py_result = compute_func(py_positions, py_atomic_numbers,
                                          py_cell, py_pbc);

        result->energy = py_result["energy"].cast<double>();
        result->num_atoms = num_atoms;
        result->success = 1;
        result->error_msg[0] = '\0';

        result->forces = new double[num_atoms * 3];
        py::list forces_list = py_result["forces"];
        for (int i = 0; i < num_atoms; ++i) {
            py::list force = forces_list[i];
            result->forces[i*3 + 0] = force[0].cast<double>();
            result->forces[i*3 + 1] = force[1].cast<double>();
            result->forces[i*3 + 2] = force[2].cast<double>();
        }

    } catch (const std::exception& e) {
        result->success = 0;
        strncpy(result->error_msg, e.what(), sizeof(result->error_msg) - 1);
    }
}

void mace_free_forces(double* forces) {
    delete[] forces;
}

void mace_free_result(MACEResult* result) {
    if (result && result->forces) {
        mace_free_forces(result->forces);
        result->forces = nullptr;
    }
}

void mace_destroy(MACEHandle handle) {
    if (!handle) return;

    MACECalculator* calc = static_cast<MACECalculator*>(handle);
    delete calc->mace_module;

    g_init_count--;
    if (g_init_count == 0 && g_interpreter) {
        delete g_interpreter;
        g_interpreter = nullptr;
    }

    delete calc;
}

const char* mace_get_error(MACEHandle handle) {
    if (!handle) return "Invalid handle";
    MACECalculator* calc = static_cast<MACECalculator*>(handle);
    return calc->last_error.c_str();
}

}
