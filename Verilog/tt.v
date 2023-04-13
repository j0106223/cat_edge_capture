`timescale 1ns/1ps
module tt ();
    reg [31:0]index;
    integer i;
    initial begin
        for(i = 0;i < 100;i = i + 1)begin
            #1;
            $display("%d",i);
        end
        $finish;
    end
    initial begin
        i = 0;
        forever begin
            #1;
            $display("%d",i);
        end
    end
endmodule