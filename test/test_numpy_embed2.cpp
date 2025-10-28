#include <pybind11/embed.h>
#include <iostream>

namespace py = pybind11;

int main() {
    std::cout << "=== Testing pybind11 with path cleaning ===" << std::endl;

    py::scoped_interpreter guard{};

    std::cout << "Python interpreter started" << std::endl;

    try {
        py::module_ sys = py::module_::import("sys");
        py::list path = sys.attr("path");

        std::cout << "\nOriginal Python sys.path:" << std::endl;
        for (auto item : path) {
            std::string p = py::str(item).cast<std::string>();
            std::cout << "  '" << p << "'" << std::endl;
        }

        // Remove empty string and current directory
        std::cout << "\nRemoving empty path entries..." << std::endl;
        while (true) {
            try {
                path.attr("remove")("");
            } catch (...) {
                break;
            }
        }

        while (true) {
            try {
                path.attr("remove")(".");
            } catch (...) {
                break;
            }
        }

        std::cout << "\nCleaned Python sys.path:" << std::endl;
        for (auto item : path) {
            std::cout << "  '" << py::str(item).cast<std::string>() << "'" << std::endl;
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
