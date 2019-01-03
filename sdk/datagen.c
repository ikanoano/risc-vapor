#include <stdio.h>
#include <stdlib.h>

/**********************************************************************/
#define SIZE (64*1024) // 256KB memory in word

/**********************************************************************/
#define VALUE_MAX (0xffffff)

unsigned int GetRandom()
{
    return (int)(rand()*(VALUE_MAX+1.0)/(1.0+RAND_MAX));
}

/**********************************************************************/
struct data_t {
    unsigned int buf[SIZE-1];  // 256KB -4Byte buffer
    int n;                     // the number of elements
};

/**********************************************************************/
int main(int argc, char *argv[])
{
    unsigned int i;
    
    struct data_t data;

    if (argc != 3) {
        fprintf(stderr, "## Usage: ./data_gen i random_seed\n");
        fprintf(stderr, "##      : n = i * 1024n");
        exit(1);
    }
    
    int random_seed = atoi(argv[2]);
    srand(random_seed);
    
    for (i=0; i<SIZE-1; i++){
        data.buf[i] = GetRandom();
    }

    data.n = atoi(argv[1]) * 1024;
    
    fwrite(&data, sizeof(unsigned int), SIZE, stdout);
    
    return 0;
}
/**********************************************************************/
