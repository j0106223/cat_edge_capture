#include<stdio.h>
#include<stdlib.h>

int main(void){
    printf("test bmp\n");
    FILE *fp;
    FILE *fpo;
    FILE *fpx;
    FILE *fpy;
    fpx = fopen("edgeX.bmp","wb");
    fpy = fopen("edgeY.bmp","wb");
    fpo = fopen("cat_gray.bmp","wb");
    fp = fopen("cat.bmp","rb");
    if(fp == NULL){
        printf("fail open file");
        exit(1);
    }
    if(fpo == NULL){
        printf("fail open file cat_gray.bmp");
        exit(1);
    }
    if(fpx == NULL){
        printf("fail open file edgeX.bmp");
        exit(1);
    }
    if(fpy == NULL){
        printf("fail open file edgeY.bmp");
        exit(1);
    }
    printf("success open\n");
    unsigned int file_size;
    unsigned int width;
    unsigned int high;
    unsigned int img_base;
    unsigned int compress;
    unsigned short int color_depth;
    unsigned int row_size;
    unsigned char header[54];    
    //read one block 54 bytes data into header array 
    //it content header information
    fread(header, 54, 1, fp);
    fwrite(header,54, 1, fpo);
    fwrite(header,54, 1, fpx);
    fwrite(header,54, 1, fpy);

    file_size   = *(unsigned int * )&header[0x02];
    compress    = *(unsigned int * )&header[0x1E];
    color_depth = *(unsigned short int *)&header[0x1C];
    img_base    = *(unsigned int * )&header[0x0A];
    width       = *(unsigned int * )&header[0x12];
    high        = *(unsigned int * )&header[0x16];
    printf("file size is      :%u\n",file_size);
    printf("compress type is  :%u\n",compress);
    printf("color_depth is    :%hu\n",color_depth);
    printf("img base offset is:%u\n",img_base);
    printf("width is          :%u\n",width);
    printf("high is           :%u\n",high);
    unsigned char pixel[3];
    unsigned char gray;
    int stride = (width * 3 + 3) & ~3;
    int padding = stride - width * 3;
    char *memory = malloc(sizeof(unsigned char) * (width + 2) * (high + 2));
    if(memory == NULL){
        printf("malloc fail...\n");
        exit(1);
    }
    /*init memory:use memset function could be danger*/
    for(int i = 0; i < (width + 2) * (high + 2); i++){
        memory[i] = 0;
    }
    for(int y = 0; y < high; y++){
        for(int x = 0; x < width; x++){
            fread(pixel, 3, 1, fp);
            gray = pixel[0] * 0.299 + pixel[1] * 0.587 + pixel[2] * 0.114;
            memory[(y+1) * (width + 2) + (x+1)] = gray;//store to memory
            pixel[0] = gray;
            pixel[1] = gray;
            pixel[2] = gray;
            fwrite(pixel, 3, 1, fpo);
        }
        //padding
        fread(pixel,padding,1,fp);
        fwrite(pixel,padding,1,fpo);
    }
    fclose(fp);
    fclose(fpo);
    //edge detection
    int Gx[3][3] = {
                      {-1, 0, 1},
                      {-2, 0, 2},
                      {-1, 0, 1}
                    };
    int Gy[3][3] = {
                      { 1, 2, 1},
                      { 0, 0, 0},
                      {-1,-2 ,1}
                    };
    short int temp = 0;
    for(int y = 1; y < high + 1; y++){
        for(int x = 1; x < width + 1; x++){
            /*Top*/
            temp += memory[(y-1) * (width + 2) + (x-1)]*Gx[0][0];
            temp += memory[(y-1) * (width + 2) + x]*Gx[0][1];
            temp += memory[(y-1) * (width + 2) + (x+1)]*Gx[0][2];
            /*Middle*/
            temp += memory[y * (width + 2) + (x-1)]*Gx[1][0];
            temp += memory[y * (width + 2) + x]*Gx[1][1];
            temp += memory[y * (width + 2) + (x+1)]*Gx[1][2];
            /*button*/
            temp += memory[(y+1) * (width + 2) + (x-1)]*Gx[2][0];
            temp += memory[(y+1) * (width + 2) + x]*Gx[2][1];
            temp += memory[(y+1) * (width + 2) + (x+1)]*Gx[2][2];
            if(temp > 100){
                temp = 255;
            }else{
                temp = 0;
            }
            pixel[0] = (unsigned char)(temp & 0xFFFF);
            pixel[1] = (unsigned char)(temp & 0xFFFF);
            pixel[2] = (unsigned char)(temp & 0xFFFF);
            fwrite(pixel, 3, 1, fpx);
            temp = 0;
            temp += memory[(y-1) * (width + 2) + (x-1)]*Gy[0][0];
            temp += memory[(y-1) * (width + 2) + x]*Gy[0][1];
            temp += memory[(y-1) * (width + 2) + (x+1)]*Gy[0][2];
            /*Middle*/
            temp += memory[y * (width + 2) + (x-1)]*Gy[1][0];
            temp += memory[y * (width + 2) + x]*Gy[1][1];
            temp += memory[y * (width + 2) + (x+1)]*Gy[1][2];
            /*button*/
            temp += memory[(y+1) * (width + 2) + (x-1)]*Gy[2][0];
            temp += memory[(y+1) * (width + 2) + x]*Gy[2][1];
            temp += memory[(y+1) * (width + 2) + (x+1)]*Gy[2][2];
            if(temp > 100){
                temp = 255;
            }else{
                temp = 0;
            }
            pixel[0] = (unsigned char)(temp & 0xFFFF);
            pixel[1] = (unsigned char)(temp & 0xFFFF);
            pixel[2] = (unsigned char)(temp & 0xFFFF);
            fwrite(pixel, 3, 1, fpy);
            temp = 0;
        }
        fwrite(pixel,padding,1,fpx);
        fwrite(pixel,padding,1,fpy);
    }
    free(memory);
    fclose(fpx);
    fclose(fpy);
    return 0;
}