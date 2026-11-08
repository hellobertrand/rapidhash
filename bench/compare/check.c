/* Bit-exactness: old vs new, all variants, lengths 0..2048, 8 alignments, 8 seeds, plus ~1MB inputs. */
#include <stdio.h>
#include <stdlib.h>
#include "decl.h"
static uint64_t x=0x123456789abcdefull; static uint64_t rnd(void){x^=x<<13;x^=x>>7;x^=x<<17;return x;}
int main(void){
  static unsigned char buf[2048+16]; for(size_t i=0;i<sizeof buf;i++) buf[i]=(unsigned char)rnd();
  const uint64_t seeds[4]={0,1,0xffffffffffffffffull,0x2d358dccaa6c78a5ull};
  struct {const char*n; hf r,w;} P[]={{"rapidhash",ref_h0,new_h0},{"Micro",ref_m0,new_m0},{"Nano",ref_n0,new_n0},
    {"rapidhash_withSeed",ref_h,new_h},{"Micro_withSeed",ref_m,new_m},{"Nano_withSeed",ref_n,new_n}};
  long n=0,bad=0;
  for(int si=0;si<8;si++){ uint64_t s=si<4?seeds[si]:rnd();
    for(size_t off=0;off<8;off++) for(size_t l=0;l<=2048;l++) for(int pi=0;pi<6;pi++){
      const unsigned char*k=buf+off; uint64_t a=P[pi].r(k,l,s), b=P[pi].w(k,l,s); n++;
      if(a!=b && bad++<10) printf("MISMATCH %s len=%zu off=%zu seed=%llx\n",P[pi].n,l,off,(unsigned long long)s); }}
  size_t bl=1<<20; unsigned char*big=malloc(bl); for(size_t i=0;i<bl;i++) big[i]=(unsigned char)rnd();
  for(size_t l=bl-300;l<=bl;l++) for(int pi=3;pi<6;pi++){ n++; if(P[pi].r(big,l,7)!=P[pi].w(big,l,7) && bad++<10) printf("MISMATCH %s len=%zu\n",P[pi].n,l); }
  printf("bit-exact check: %ld comparisons, %ld mismatches\n",n,bad); return bad!=0;
}
