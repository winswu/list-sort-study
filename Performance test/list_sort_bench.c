#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <inttypes.h>

#include <linux/list.h>   // from tools/include/linux/list.h
#include <linux/kernel.h> // for container_of etc.

void list_sort(void *priv, struct list_head *head,
               int (*cmp)(void *priv, const struct list_head *a,
                          const struct list_head *b));

struct item
{
    long key;
    struct list_head node;
};

static uint64_t g_comparisons = 0;

static inline long rndlong(void)
{
    // 簡單 PRNG
    static uint64_t x = 88172645463393265ull;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    return (long)(x & 0x7fffffffffffffffULL);
}

static int cmp_long(void *priv, const struct list_head *a, const struct list_head *b)
{
    (void)priv;
    g_comparisons++;
    const struct item *ia = list_entry(a, struct item, node);
    const struct item *ib = list_entry(b, struct item, node);
    if (ia->key < ib->key)
        return -1;
    if (ia->key > ib->key)
        return 1;
    return 0;
}

static struct item *alloc_items(size_t n)
{
    struct item *arr = (struct item *)malloc(sizeof(struct item) * n);
    if (!arr)
    {
        perror("malloc");
        exit(1);
    }
    return arr;
}

static void build_list(struct list_head *head, struct item *arr, size_t n)
{
    INIT_LIST_HEAD(head);
    for (size_t i = 0; i < n; ++i)
    {
        INIT_LIST_HEAD(&arr[i].node);
        list_add_tail(&arr[i].node, head);
    }
}

static void fill_random(struct item *arr, size_t n)
{
    for (size_t i = 0; i < n; ++i)
        arr[i].key = rndlong();
}

static void fill_ascending(struct item *arr, size_t n)
{
    for (size_t i = 0; i < n; ++i)
        arr[i].key = (long)i;
}

static void fill_descending(struct item *arr, size_t n)
{
    for (size_t i = 0; i < n; ++i)
        arr[i].key = (long)(n - 1 - i);
}

// organ-pipe: 0,1,2,...,mid,...,2,1,0
static void fill_organpipe(struct item *arr, size_t n)
{
    size_t mid = n / 2;
    for (size_t i = 0; i < n; ++i)
    {
        size_t d = (i <= mid) ? i : (n - 1 - i);
        arr[i].key = (long)d;
    }
}

// sawtooth: i % m
static void fill_sawtooth(struct item *arr, size_t n, size_t m)
{
    if (m == 0)
        m = 1;
    for (size_t i = 0; i < n; ++i)
        arr[i].key = (long)(i % m);
}

// staggered: i*m + (i % m) 近似 sortperf 的「Staggered」
static void fill_staggered(struct item *arr, size_t n, size_t m)
{
    if (m == 0)
        m = 1;
    for (size_t i = 0; i < n; ++i)
        arr[i].key = (long)(i * m + (i % m));
}

static int is_sorted(struct list_head *head)
{
    if (list_empty(head))
        return 1;
    struct list_head *pos;
    long prev = list_entry(head->next, struct item, node)->key;
    list_for_each(pos, head)
    {
        long k = list_entry(pos, struct item, node)->key;
        if (k < prev)
            return 0;
        prev = k;
    }
    return 1;
}

static uint64_t nsec_now(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + ts.tv_nsec;
}

static void bench_once(const char *pattern, size_t n, size_t param)
{
    struct item *arr = alloc_items(n);
    if (!strcmp(pattern, "random"))
        fill_random(arr, n);
    else if (!strcmp(pattern, "ascending"))
        fill_ascending(arr, n);
    else if (!strcmp(pattern, "descending"))
        fill_descending(arr, n);
    else if (!strcmp(pattern, "organpipe"))
        fill_organpipe(arr, n);
    else if (!strcmp(pattern, "sawtooth"))
        fill_sawtooth(arr, n, param ? param : 32);
    else if (!strcmp(pattern, "staggered"))
        fill_staggered(arr, n, param ? param : 32);
    else
    {
        fprintf(stderr, "Unknown pattern: %s\n", pattern);
        exit(2);
    }

    struct list_head head;
    build_list(&head, arr, n);

    g_comparisons = 0;
    uint64_t t0 = nsec_now();
    list_sort(NULL, &head, cmp_long);
    uint64_t t1 = nsec_now();

    if (!is_sorted(&head))
    {
        fprintf(stderr, "ERROR: result not sorted!\n");
        exit(3);
    }

    printf("%s,%zu,%" PRIu64 ",%" PRIu64 "\n",
           pattern, n, (t1 - t0), g_comparisons);

    free(arr);
}

static void usage(const char *argv0)
{
    fprintf(stderr, "Usage: %s <n> [param]\n", argv0);
}

int main(int argc, char **argv)
{
    if (argc < 2)
    {
        usage(argv[0]);
        return 1;
    }
    size_t n = strtoull(argv[1], NULL, 10);
    size_t param = (argc >= 3) ? strtoull(argv[2], NULL, 10) : 0;

    printf("pattern,n,time_ns,comparisons\n");
    bench_once("random", n, param);
    bench_once("ascending", n, param);
    bench_once("descending", n, param);
    bench_once("organpipe", n, param);
    bench_once("sawtooth", n, param);
    bench_once("staggered", n, param);

    return 0;
}
