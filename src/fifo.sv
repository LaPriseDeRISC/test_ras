`timescale 1ns / 1ps

module fifo (clk, rst, wen, pop, empty, din, dout);
    parameter DEPTH = 1024;
    parameter WIDTH = 36;
    parameter ADDR = 10;
    input clk, rst, wen, pop;
    output reg empty;
    input [WIDTH-1:0] din;
    output logic [WIDTH-1:0] dout;
    reg [WIDTH-1:0] ram [DEPTH-1:0];
    reg [ADDR-1:0] raddr, waddr;
    
    always @(posedge clk)
    begin
        if (rst)
        begin
            raddr <= '0;
            waddr <= '0;
        end else begin 
            dout <= ram[raddr];
            if (pop) begin
                 raddr <= raddr + 1'b1;
            end 
            if (wen) begin
                 ram[waddr] <= din;
                 waddr <= waddr + 1'b1;
            end
            if(pop) empty <= (((raddr + 1'b1 == waddr) && (!wen)) ? 1'b1 : 1'b0);
            else empty <= (wen ? 1'b0 : empty);
        end
    end
    
endmodule

