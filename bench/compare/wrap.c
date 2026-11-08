/* Compiled twice: -DPFX=ref against the old header, -DPFX=new against the new one. */
#include <stdint.h>
#include <stddef.h>
#include "rapidhash.h"
#define CAT2(a,b) a##_##b
#define CAT(a,b) CAT2(a,b)
#define F(n) CAT(PFX,n)
uint64_t F(h0)(const void*k,size_t l,uint64_t s){(void)s; return rapidhash(k,l);}
uint64_t F(m0)(const void*k,size_t l,uint64_t s){(void)s; return rapidhashMicro(k,l);}
uint64_t F(n0)(const void*k,size_t l,uint64_t s){(void)s; return rapidhashNano(k,l);}
uint64_t F(h)(const void*k,size_t l,uint64_t s){return rapidhash_withSeed(k,l,s);}
uint64_t F(m)(const void*k,size_t l,uint64_t s){return rapidhashMicro_withSeed(k,l,s);}
uint64_t F(n)(const void*k,size_t l,uint64_t s){return rapidhashNano_withSeed(k,l,s);}
