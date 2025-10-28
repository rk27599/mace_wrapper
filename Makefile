# ============================================================
# MACE Wrapper Shared Library - Isolated Python
# ============================================================

ISOLATED_PYTHON_HOME = $(HOME)/mace_python
PYTHON_BIN = $(ISOLATED_PYTHON_HOME)/bin/python3
PYTHON_CONFIG = $(ISOLATED_PYTHON_HOME)/bin/python3-config

CXX = g++
CXXFLAGS = -std=c++17 -O3 -Wall -Wextra -fPIC -shared

# Set LD_LIBRARY_PATH for Python shell commands
PYTHON_INCLUDES := $(shell LD_LIBRARY_PATH=$(ISOLATED_PYTHON_HOME)/lib:$$LD_LIBRARY_PATH $(PYTHON_CONFIG) --includes)
PYTHON_LDFLAGS := $(shell LD_LIBRARY_PATH=$(ISOLATED_PYTHON_HOME)/lib:$$LD_LIBRARY_PATH $(PYTHON_CONFIG) --ldflags --embed 2>/dev/null || LD_LIBRARY_PATH=$(ISOLATED_PYTHON_HOME)/lib:$$LD_LIBRARY_PATH $(PYTHON_CONFIG) --ldflags)
PYBIND11_INCLUDES := $(shell LD_LIBRARY_PATH=$(ISOLATED_PYTHON_HOME)/lib:$$LD_LIBRARY_PATH $(PYTHON_BIN) -m pybind11 --includes)

ALL_INCLUDES = $(PYBIND11_INCLUDES) -Iinclude
ISOLATED_LIB_DIR = $(ISOLATED_PYTHON_HOME)/lib
ALL_LDFLAGS = $(PYTHON_LDFLAGS)
ALL_RPATH = -Wl,-rpath,$(ISOLATED_LIB_DIR)
ALL_LIBS = -lpthread -ldl -lutil -lm

LIB_NAME = mace_wrapper_v1
LIB_SO = lib/lib$(LIB_NAME).so

SOURCES = src/mace_wrapper.cpp
OBJECTS = $(SOURCES:.cpp=.o)

.PHONY: all clean info test run

all: $(LIB_SO)

$(LIB_SO): $(SOURCES)
	@mkdir -p lib
	@echo "Building isolated MACE wrapper..."
	$(CXX) $(CXXFLAGS) $(ALL_INCLUDES) $(SOURCES) \
		$(ALL_LDFLAGS) $(ALL_RPATH) $(ALL_LIBS) -o $@
	@echo "Library built: $@"
	@ldd $@ | grep -E "python|libc.so" || true

clean:
	rm -rf lib src/*.o

info:
	@echo "=== Build Configuration ==="
	@echo "Python home: $(ISOLATED_PYTHON_HOME)"
	@echo "Python binary: $(PYTHON_BIN)"
	@echo "Includes: $(ALL_INCLUDES)"
	@echo "Python version:"
	@$(PYTHON_BIN) --version
	@echo "MACE installed: "
	@$(PYTHON_BIN) -c "import mace; print(mace.__version__)" 2>/dev/null || echo "Not found"
	@echo ""

test: $(LIB_SO)
	@echo "Testing MACE wrapper..."
	@export LD_LIBRARY_PATH=$(ISOLATED_LIB_DIR):$$LD_LIBRARY_PATH && \
	 export PYTHONPATH=$(PWD)/python:$$PYTHONPATH && \
	 $(CXX) -std=c++17 -I$(PWD)/include test/test_mace.cpp \
	 -L$(PWD)/lib -l$(LIB_NAME) \
	 -Wl,-rpath,$(PWD)/lib:$(ISOLATED_LIB_DIR) -o /tmp/test_mace_app && \
	 cd /tmp && ./test_mace_app
