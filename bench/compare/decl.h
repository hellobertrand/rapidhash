#include <stdint.h>
#include <stddef.h>
typedef uint64_t (*hf)(const void*, size_t, uint64_t);
#define D(p) uint64_t p##_h0(const void*,size_t,uint64_t), p##_m0(const void*,size_t,uint64_t), p##_n0(const void*,size_t,uint64_t), \
                      p##_h(const void*,size_t,uint64_t),  p##_m(const void*,size_t,uint64_t),  p##_n(const void*,size_t,uint64_t);
D(ref) D(new)
#ifdef HAS_PREMIX
uint64_t new_pm(uint64_t), new_hp(const void*,size_t,uint64_t), new_mp(const void*,size_t,uint64_t), new_np(const void*,size_t,uint64_t);
#define PREMIX(s) new_pm(s)
#else
#define PREMIX(s) (s)
#endif
