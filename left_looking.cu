#include <cuda_runtime.h>
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>       // needed for the function sqrtf()

#define TILE_SIZE 32 // NB // Block SIZE

/*
 * Function to perform rank-k update 
 * half of the threads working
 */
__device__ void ssyrk_tile(float* rA1, float* rA2) 
{
    int row = blockIdx.y * TILE_SIZE + threadIdx.y;
    int column = blockIdx.x * TILE_SIZE + threadIdx.x;

    if(column <= row)
    {
        float updatedValue = rA2[row * TILE_SIZE + column];

        for(int k=0; i<TILE_SIZE; k++)
        {
            updatedValue -= rA1[row * TILE_SIZE + k] * rA1[column * TILE_SIZE + k];
        }

        rA2[row * TILE_SIZE + column] = updatedValue;
    }
}


/*
 * Function to perform general matrix multiplication 
 * DOUBT: I think calculation is given wrong in paper it should be rA2[k][n] 
 */
__device__ void sgemm_tile(const float* rA1, const float* rA2, float* rA3)
{
    int row = blockIdx.y * TILE_SIZE + threadIdx.y;
    int column = blockIdx.x * TILE_SIZE + threadIdx.x;


    float updatedValue = rA3[row * TILE_SIZE + column];

    for(int i=0; i<TILE_SIZE; i++)
    {
        updatedValue -= rA1[row * TILE_SIZE + i] * rA2[i * TILE_SIZE + column];
    }

    rA3[row * TILE_SIZE + column] = updatedValue;
}


/*
 * Function to store full tile from shared memory to global memory  
 */
__device__ void store_full(const float* s_data, float* g_data)
{
    int row = blockIdx.y * TILE_SIZE + threadIdx.y;
    int column = blockIdx.x * TILE_SIZE + threadIdx.x;

    g_data[row * TILE_SIZE + column] = s_data[row * TILE_SIZE + column];

    __syncthreads();
}


/*
 * Function to store lower triangular tile from shared memory to global memory  
 */
__device__ void store_lower(const float* s_data, float* g_data)
{
    int row = blockIdx.y * TILE_SIZE + threadIdx.y;
    int column = blockIdx.x * TILE_SIZE + threadIdx.x;

    if(column <= row)
        g_data[row * TILE_SIZE + column] = s_data[row * TILE_SIZE + column];
    else
        g_data[row * TILE_SIZE + column] = 0;

    __syncthreads();
}


/*#include <math.h>       // needed for the function sqrtf()
# define tile_width 32*/

/*
* Function to perform Choleshky Factorization for a tile
*/
__device__ void spotrf_tile(float* t_A)
{
    int ty = blockIdx.x*blockdim.x + threadIdx.x;  // col
    int tx = blockIdx.y*blockdim.y + threadIdx.y; // row

    for(int k{0};k<tile_width;k++){
        // square root of diagonal elements

        if(tx==0 && ty==0)
            t_A[k*tile_width + k] = sqrtf(t_A[k*tile_width + k]);
        __syncthreads();

        // division step done parallaly
        if(ty<=tx && tx<tile_width && ty<tile_width)
        {
            t_A[(tx+1)*tile_width + k]/= t_A[k*tile_width + k];
        }
        __syncthreads();

        if(ty<=tx && tx<tile_width && ty<tile_width){
            t_A[(tx+1)*tile_width + (ty+1)]-= t_A[(tx+1)*tile_width + k]*t_A[(ty+1)*tile_width + k];
        }
        __syncthreads();
    }
}

/*
* Function to perform triangular solve for a tile 
*/

__device__ void strsm_tile(float *t_A1, float *t_A2)
{
    // t_A2 is current unkonown 
    int ty = blockIdx.x*blockdim.x + threadIdx.x;
    int tx = blockIdx.y*blockdim.y + threadIdx.y;

    // use syncthreads to remove both top loops
    for(int m{0};m<tile_width;m++){
        for(int k{0};k<tile_width;k++){
            if(tx==0 && ty==0)
                t_A2[m*tile_width +k]/= t_A1[k*tile_width+k];
            __syncthreads();
    
            if(ty<=tx && tx<tile_width && ty<tile_width)
            {
                t_A2[m*tile_width + tx+1+k]-= t_A2[m*tile_width + k]*t_A1[(tx+1+k)*tile_width + k];
                __syncthreads();
            }

        }
    }
 
}

/*
* Function to load a full tile from global memory to shared memory
*/

__device__ void load_full(float *t_A,float * S_A)
{
    // assigning a 2-D array in shared memory 

    int ty = blockIdx.x*blockdim.x + threadIdx.x;  // col
    int tx = blockIdx.y*blockdim.y + threadIdx.y; // row

    if(tx<tile_width && ty<tile_width)
        S_A[tx*tile_width+ty] = t_A[tx*tile_width + ty];
    __syncthreads();

}