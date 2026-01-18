CC ?= gcc
CFLAGS ?= -O3 -march=native -Wall -Wextra
PERF_DIR := Performance\ test
KBASE := third_party/linux
KTOOLS_INC := $(KBASE)/tools/include
KTOOLS_UAPI := $(KBASE)/tools/include/uapi
KLIB := $(KBASE)/lib
SHIM_INC := $(PERF_DIR)/include_shim

OBJS := list_sort_bench.o list_sort.o

all: list_sort_bench

list_sort_bench: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^

list_sort_bench.o: $(PERF_DIR)/list_sort_bench.c
	$(CC) $(CFLAGS) -I$(KTOOLS_INC) -c "$<" -o $@

list_sort.o: $(KLIB)/list_sort.c
	$(CC) $(CFLAGS) -I$(SHIM_INC) -I$(KTOOLS_INC) -I$(KTOOLS_UAPI) -c "$<" -o $@

clean:
	rm -f list_sort_bench $(OBJS)
