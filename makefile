CC ?= gcc
CFLAGS ?= -O3 -march=native -Wall -Wextra
PERF_DIR := Performance\ test
KBASE := third_party/linux
KTOOLS_INC := $(KBASE)/tools/include
KTOOLS_UAPI := $(KBASE)/tools/include/uapi
KLIB := $(KBASE)/lib
SHIM_INC := $(PERF_DIR)/include_shim
BUILD_DIR := build

BIN := $(BUILD_DIR)/list_sort_bench
OBJS := $(BUILD_DIR)/list_sort_bench.o $(BUILD_DIR)/list_sort.o

all: $(BIN)

$(BIN): $(OBJS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $^

$(BUILD_DIR):
	mkdir -p "$@"

$(BUILD_DIR)/list_sort_bench.o: $(PERF_DIR)/list_sort_bench.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -I$(KTOOLS_INC) -c "$<" -o $@

$(BUILD_DIR)/list_sort.o: $(KLIB)/list_sort.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -I$(SHIM_INC) -I$(KTOOLS_INC) -I$(KTOOLS_UAPI) -c "$<" -o $@

clean-build:
	rm -f $(BIN) $(OBJS) list_sort_bench
	@if [ -d "$(BUILD_DIR)" ]; then rmdir --ignore-fail-on-non-empty "$(BUILD_DIR)"; fi

clean: clean-build
	rm -rf bench_results
