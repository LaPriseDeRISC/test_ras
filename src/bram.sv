`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/10/2023 03:45:04 PM
// Design Name: 
// Module Name: ras_impl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

 // Dual-Port Block RAM with Two Write Ports

// File: rams_tdp_rf_rf.v

module bram (clk,ena,enb,wea,web,addra,addrb,dia,dib,doa,dob);
    parameter DEPTH = 1024;
    parameter WIDTH = 36;
    parameter ADDR = 10;
    parameter OFS = 0;
    parameter BLANK = 1;
    input clk,ena,enb,wea,web;
    input [ADDR-1:0] addra,addrb;
    input [WIDTH-1:0] dia,dib;
    output logic [WIDTH-1:0] doa,dob;
    reg [WIDTH-1:0] ram [DEPTH-1:0]/*verilator public*/;
    generate 
        if(! BLANK) begin
            for(genvar i = 0; i< DEPTH; i++) begin
                initial ram[i] = WIDTH'(i + OFS);
            end
        end
    endgenerate 
    
    always @(posedge clk)
    begin
        if (ena)
        begin
            if (wea) begin
                ram[addra] <= dia;
                doa <= dia;
            end else doa <= ram[addra];
        end
    end
    always @(posedge clk)
    begin
        if (enb)
        begin
            if (web) begin
                ram[addrb] <= dib;
                dob <= dib;
            end else dob <= ram[addrb];
        end
    end
endmodule 


