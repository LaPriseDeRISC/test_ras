`timescale 1ns / 1ps

module fifo (clk, rst, wen, pop, empty, din, dout);
    parameter DEPTH = 1024;
    parameter WIDTH = 36;
    parameter ADDR = 10;
    input clk, rst, wen, pop;
    output logic empty;
    input [WIDTH-1:0] din;
    output logic [WIDTH-1:0] dout;
    reg [WIDTH-1:0] ram [DEPTH-1:0];
    logic [ADDR-1:0] raddr, waddr;
    initial empty = 1'b1;
    
    always @(posedge clk)
    begin
        if (rst)
        begin
            raddr <= '0;
            waddr <= '0;
            empty <= '0;
        end else begin 
            if(pop && wen && waddr == raddr) dout <= din; //write_first
            else dout <= ram[raddr];
            if (pop) begin
                 raddr <= raddr + 1'b1;
            end 
            if (wen) begin
                 ram[waddr] <= din;
                 waddr <= waddr + 1'b1;
            end
            if(pop ^ wen) begin
                if(pop) 
                    empty <= ((raddr + 1'b1 == waddr) ? 1'b1 : 1'b0);
                else // wen
                    empty <= 1'b0;
            end             
        end
    end
    
endmodule

