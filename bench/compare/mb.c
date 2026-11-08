/* Micro-benchmark old vs new. Usage: mb [len...]   (default: a size sweep from 0 B to 512 KB)
 * thr = independent calls (throughput), lat = next input offset depends on previous hash (latency).
 * Each figure is the minimum of 7 repetitions. Positive gain = new is faster. */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "decl.h"
static unsigned char *buf;
static volatile uint64_t g_seed = 0x1234567;
static double now(void){struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec*1e9+t.tv_nsec;}
static double thr(hf f,size_t len,long it,uint64_t s){uint64_t acc=0; double t=now(); for(long i=0;i<it;i++) acc+=f(buf+(i&63),len,s); t=now()-t; if(acc==42) puts(""); return t/it;}
static double lat(hf f,size_t len,long it,uint64_t s){uint64_t h=0; double t=now(); for(long i=0;i<it;i++) h=f(buf+((h^(uint64_t)i)&63),len,s); t=now()-t; if(h==42) puts(""); return t/it;}
int main(int argc,char**argv){
  size_t def[]={0,3,8,12,16,17,24,32,48,64,96,112,113,128,200,256,512,1024,4096,16384,262144,524288};
  size_t L[64], nl=0, maxl=0;
  if(argc>1) for(int a=1;a<argc&&nl<64;a++) L[nl++]=strtoul(argv[a],0,10); else for(;nl<sizeof def/sizeof*def;nl++) L[nl]=def[nl];
  for(size_t i=0;i<nl;i++) if(L[i]>maxl) maxl=L[i];
  buf=malloc(maxl+128); for(size_t i=0;i<maxl+128;i++) buf[i]=(unsigned char)(i*2654435761u>>13);
  uint64_t s=g_seed;
  struct {const char*n; hf r,w;} P[]={{"rapidhash",ref_h0,new_h0},{"Micro",ref_m0,new_m0},{"Nano",ref_n0,new_n0},
    {"withSeed",ref_h,new_h}};
  printf("%-10s %7s | %10s %10s %7s | %10s %10s %7s\n","variant","len","thr old","thr new","gain","lat old","lat new","gain");
  for(int pi=0;pi<4;pi++){ for(size_t li=0;li<nl;li++){ size_t len=L[li];
    long it = len<=256 ? 20000000 : 200000000/(long)len; if(it<2000) it=2000;
    double tr=1e18,tn=1e18,lr=1e18,ln=1e18, v;
    for(int rep=0;rep<7;rep++){
      v=thr(P[pi].r,len,it,s); if(v<tr)tr=v;  v=thr(P[pi].w,len,it,s); if(v<tn)tn=v;
      v=lat(P[pi].r,len,it,s); if(v<lr)lr=v;  v=lat(P[pi].w,len,it,s); if(v<ln)ln=v; }
    printf("%-10s %7zu | %8.2fns %8.2fns %+6.1f%% | %8.2fns %8.2fns %+6.1f%%\n",P[pi].n,len,tr,tn,(tr/tn-1)*100,lr,ln,(lr/ln-1)*100);
    fflush(stdout); } }
  return 0;
}
