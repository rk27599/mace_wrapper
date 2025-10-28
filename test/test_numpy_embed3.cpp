#include <pybind11/embed.h>
#include <iostream>
#include <cstdlib>

namespace py = pybind11;

int main() {
    std::cout << "=== Testing pybind11 with PYTHONHOME ===" << std::endl;

    // Set PYTHONHOME to isolated Python installation in user home directory
    const char* home = getenv("HOME");
    if (home != nullptr) {
        std::string python_home = std::string(home) + "/mace_python";
        setenv("PYTHONHOME", python_home.c_str(), 1);
    } else {
        std::cerr << "Error: HOME environment variable not set" << std::endl;
        return 1;
    }

    py::scoped_interpreter guard{};

    std::cout << "Python interpreter started" << std::endl;

    try {
        py::module_ sys = py::module_::import("sys");
        py::list path = sys.attr("path");

        std::cout << "\nPython sys.path:" << std::endl;
        for (auto item : path) {
            std::cout << "  " << py::str(item).cast<std::string>() << std::endl;
        }

        // Remove empty string
        while (true) {
            try {
                path.attr("remove")("");
            } catch (...) {
                break;
            }
        }

        std::cout << "\nTrying to import numpy..." << std::endl;
        py::module_ np = py::module_::import("numpy");
        std::cout << "✓ numpy imported successfully" << std::endl;
        std::cout << "  Version: " << py::str(np.attr("__version__")).cast<std::string>() << std::endl;

    } catch (const std::exception& e) {
        std::cerr << "✗ Error: " << e.what() << std::endl;
        return 1;
    }

    std::cout << "\n=== Test passed ===" << std::endl;
    return 0;
}
