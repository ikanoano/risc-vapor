#include <limits.h>
#include "syscalls.h"
/**********************************************************************/
extern  int _binary_bigdata_start;
extern  int _binary_bigdata_size;
#define MIN(a,b) (a<b ? a : b)

void bubble_sort(int *array, int len) {
  if(len==1) return;
  // search max value
  int max_val=INT_MIN, max_idx=0;
  for(int i=0; i<len; i++) {
    if(array[i]<=max_val) continue;
    max_val = array[i];
    max_idx = i;
  }
  // swap
  array[max_idx]  = array[len-1];
  array[len-1]    = max_val;
  // sort the rest
  printf("%010x\n", len);
  bubble_sort(array, len-1);
}

void dump_array(int *array, int len) {
  for(int i=0; i<len; i+=len/64)
    printf("%010x\n", array[i]);
  printf("\n");
}

int main() {
    int *bigdata = &_binary_bigdata_start;
    const int len = MIN(bigdata[64*1024-1], 8*1024);
    const int binary_bigdata_size = ((int)(&_binary_bigdata_size))/4;

    printf("bubble_sort\n");
    printf("len=%d\n", len);
    printf("bigdata size=%d\n", binary_bigdata_size);

    int dataset[len];
    for (int i=0; i<len; i++) {
      dataset[i] = bigdata[i % binary_bigdata_size];
    }

    printf("before\n");
    dump_array(dataset, len);

    bubble_sort(dataset, len);

    printf("after\n");
    dump_array(dataset, len);

    return 0;
}
