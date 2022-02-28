#ifndef __UTIL_H__
#define __UTIL_H__

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#define CHECK(x) assert(x);

typedef int32_t timestamp;
const timestamp MAX_TIMESTAMP = 0x7FFFFFFF;

int parseNumber(const char *s, size_t *pos, timestamp *n);

FILE *open_file_type(const char *prefix, const char *ftype, const char *mode);

#endif /* __UTIL_H__ */
