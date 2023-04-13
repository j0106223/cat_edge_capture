`timescale 1ns/1ps
`default_nettype none
`define period 20
`define WIDTH 354
`define HIGH  425
module test_bench ();
    integer fp;//FILE pointer
    integer fpg;//gray
    integer fpx;//edge x
    integer fpy;//edge y
    integer error_code;
    reg [7:0]mem[0:1000000];        //Original picture
    reg [7:0]mem_gray[0:1000000];   //Gray picture
    reg [7:0]mem_edgeX[0:1000000];  //X edgedetect picture
    reg [7:0]mem_edgeY[0:1000000];  //Y edgedetect picture
    integer width;
    integer high;
    integer img_base;
    integer stride;
    integer padding;
    integer i,j;
    integer x,y;
    reg [7:0]pixel[0:2];
    reg [7:0]R,G,B;
    reg [19:0]Y;
    reg clk;
    reg reset_n;
    reg shift_en;
    initial begin
        $dumpfile("test_bench.vcd");
        $dumpvars(0,convolution);
        $dumpvars(0,linebuf_inst);   
    end
    initial begin
        clk = 0;
        reset_n = 0;
        #(`period);
        reset_n = 1;
        forever begin
            #(`period/2) clk = ~clk;
        end
    end
    initial begin
        $display("-------------Testbench begin-------------");
        fp = $fopen("cat.bmp", "rb");
        error_code = $fread(mem, fp);
        $fclose(fp);
        fpg = $fopen("cat_gray.bmp", "wb");
        fpx = $fopen("cat_edgeX.bmp", "wb");
        fpy = $fopen("cat_edgeY.bmp", "wb");
        /*copy header to each file*/
        for(i = 0; i < 54; i = i + 1)begin//54 is header size
            $fwrite(fpg, "%c", mem[i]);
            $fwrite(fpx, "%c", mem[i]);
            $fwrite(fpy, "%c", mem[i]);
        end

        width       = {mem[8'h15], mem[8'h14], mem[8'h13], mem[8'h12]};
        high        = {mem[8'h19], mem[8'h18], mem[8'h17], mem[8'h16]};
        img_base    = {mem[8'hD] , mem[8'h0C], mem[8'h0B], mem[8'h0A]};
        stride = (width * 3 + 3) & 32'hFFFFFFFC;
        padding = stride - width * 3;
        $display("Picture width is           %d", width);
        $display("Picture high is            %d", high);
        $display("Picture img base offset is %d", img_base);
        $display("stride(row size) is        %d", stride);
        $display("you need padding           %d", padding);

        if(`WIDTH != width || `HIGH != high)begin
            $display("width or high is not same as your define");
            $display("your `WIDTH define value is %d", `WIDTH);
            $display("your picture width value is %d", width);
            $display("your `HIGH define value is  %d", `HIGH);
            $display("your picture width value is %d", high);
            $display("-------------Testbench fail-------------");
            $finish;
        end
        /*init mem_gray to 0*/
        for(i = 0; i < (width + 2) * (high + 2); i = i + 1)begin
            mem_gray[i] = 0;
        end
        i = img_base;
        for(y = 0; y < high; y = y + 1)begin
            for(x = 0; x < width; x = x + 1)begin
                R = mem[i];
                G = mem[i+1];
                B = mem[i+2];
                i = i + 3;
                Y = R * 0.299 + G * 0.587 + B * 0.114;
                mem_gray[(y + 1) * (width + 2) + (x + 1)] = Y;
                $fwrite(fpg,"%c%c%c", Y, Y, Y);
            end
            //padding
            for(j = 0;j < padding; j = j + 1)begin
                $fwrite(fpg,"%c",mem[i]);
                i = i + 1;
            end
        end
        for(i = 0;i < (width + 2) * (high + 2);i = i + 1)begin
            if(i % (width + 2) == 0)begin
                $display("");
            end
            $write("%d ", mem_gray[i]);
        end
        $display("");
        $fclose(fpg);
    end
    integer index_buf;
    initial begin//feed data to line buffer
        index_buf = 0;
        shift_en  = 1'b1;
        forever begin
            @(negedge clk)begin
                if(index_buf < (width + 2) * (high + 2))begin
                    #1 index_buf = index_buf + 1;
                end
            end
        end
    end
    integer index_conv;
    integer padding_cnt;
    integer pixel_cnt;
    initial begin//get data from conv.
        index_conv = 0;
        pixel_cnt  = 0;
        #(`period*2);
        forever begin
            @(posedge clk)begin
                if(conv_valid_w)begin
                    index_conv = index_conv + 1;
                    if(index_conv % (width + 1) != 0 && index_conv % (width + 2) != 0)begin
                        mem_edgeX[pixel_cnt] = dataGx_w;
                        mem_edgeY[pixel_cnt] = dataGy_w;
                        pixel_cnt = pixel_cnt + 1;
                        //writeback to file
                        $fwrite(fpx, "%c%c%c", dataGx_w, dataGx_w, dataGx_w);
                        $fwrite(fpy, "%c%c%c", dataGy_w, dataGy_w, dataGy_w);
                        
                        if(pixel_cnt % width == 0)begin
                            //padding, can be any value,just to fit the 4byte align
                            repeat(padding)begin
                                $fwrite(fpx, "%c", 0);
                                $fwrite(fpy, "%c", 0);
                            end
                        end
                        if(pixel_cnt >= width * high)begin
                            $fclose(fpx);
                            $fclose(fpy);
                            $display("-------------Testbench Success done-------------");
                            $finish;
                        end
                    end
                end
            end
        end
    end
    linebuf #( 
        .depth(((`WIDTH + 2) * 2 + 3)),
        .width(8)
    )linebuf_inst(
        .clk        (clk),
        .reset_n    (reset_n),
        .shift_en   (shift_en),
        .data_i     (mem_gray[index_buf]),
        //.data_i     (index_buf[7:0]),
        .tap1_o     (tap1_w),//row1
        .tap2_o     (tap2_w),//row2
        .tap3_o     (tap3_w),//row3
        .full_o     (linebuf_full_w)
    );
    wire [7:0]  tap1_w;
    wire [7:0]  tap2_w;
    wire [7:0]  tap3_w;
    wire        linebuf_full_w;
    wire        conv_valid_w;
    wire [7:0]  dataGx_w;
    wire [7:0]  dataGy_w;
    conv convolution(
        .clk        (clk),
        .reset_n    (reset_n),
        .tap1_i     (tap1_w),
        .tap2_i     (tap2_w),
        .tap3_i     (tap3_w),
        .datavalid_i(linebuf_full_w),//line buffer full
        .datavalid_o(conv_valid_w),
        .dataGx_o   (dataGx_w),
        .dataGy_o   (dataGy_w)
    );
endmodule

module conv (
    input       clk,
    input       reset_n,
    input  [7:0]tap1_i,
    input  [7:0]tap2_i,
    input  [7:0]tap3_i,
    input       datavalid_i,
    output      datavalid_o,
    output [7:0]dataGx_o,
    output [7:0]dataGy_o
);
    reg [7:0]R[0:8];
    integer i;
    reg [2:0]valid;
    assign datavalid_o = valid[2];
    always @(posedge clk or negedge reset_n) begin
        if(!reset_n)begin
            valid <= 3'b000;
        end else begin
            valid[0] <= datavalid_i;
            valid[1] <= valid[0];
            valid[2] <= valid[1];
        end
    end
    always @(posedge clk or negedge reset_n) begin
        if(!reset_n)begin
            for(i = 0; i < 9;i = i + 1)begin
                R[i] <= 8'b00000000;
            end
        end else begin
            {R[2], R[1], R[0]} <= {tap1_i, R[2], R[1]};
            {R[5], R[4], R[3]} <= {tap2_i, R[5], R[4]};
            {R[8], R[7], R[6]} <= {tap3_i, R[8], R[7]};
        end
    end
    /*Simplify
    wire signed [7:0]resultGx_w = R[0] * (-1) + R[1] * 0 + R[2] * 1
                                 +R[3] * (-2) + R[4] * 0 + R[5] * 2
                                 +R[6] * (-1) + R[7] * 0 + R[8] * 1;

    wire signed [7:0]resultGy_w = R[0] *   1  + R[1] *   2  + R[2] *   1 
                                 +R[3] *   0  + R[4] *   0  + R[5] *   0
                                 +R[6] * (-1) + R[7] * (-2) + R[8] * (-1);
    Simplify*/
    wire signed [15:0]resultGx_w = R[0] * (-1) + R[2]
                                  +R[3] * (-2) + R[5] * 2
                                  +R[6] * (-1) + R[8];
    wire signed [15:0]resultGy_w = R[0] + R[1] * 2 + R[2]
                                  +R[6] * (-1) + R[7] * (-2) + R[8] * (-1);
    assign dataGx_o = (resultGx_w > 100) ? 8'd255 : 8'd0;
    assign dataGy_o = (resultGy_w > 100) ? 8'd255 : 8'd0;
endmodule

module linebuf #(
    parameter depth = (`WIDTH + 2) * 2 + 3,
    parameter width = 8
)(
    input        clk,
    input        reset_n,
    input        shift_en,
    input  [7:0] data_i,
    output [7:0] tap1_o,//row1
    output [7:0] tap2_o,//row2
    output [7:0] tap3_o,//row3
    output       full_o
);
    localparam MSB = depth * width - 1;
    localparam ROW_SIZE = (depth - 3) / 2;
    reg [MSB:0]shift_reg;
    assign tap1_o = shift_reg[MSB-:8];
    assign tap2_o = shift_reg[23 + ROW_SIZE * 8-:8];
    assign tap3_o = shift_reg[23-:8];//[23:16]
    reg [31:0]cnt;
    always @(posedge clk or negedge reset_n) begin
        if(!reset_n)begin
            shift_reg <= 0;
            cnt       <= 0;
        end else begin
            if(shift_en)begin
                shift_reg <= {shift_reg[MSB-8:0], data_i};
                cnt <= cnt + 1'b1;
            end
        end
    end
    assign full_o = (cnt >= depth);
endmodule