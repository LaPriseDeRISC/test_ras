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

module ras_bram (clk,rea,reb,wea,web,raddra,raddrb,waddra,waddrb,wia,wib,doa,dob);
    parameter DEPTH = 1024;
    parameter WIDTH = 36;
    localparam ADDR = $clog2(DEPTH);
    parameter OFS = 0;
    parameter INCR = 0;
    input clk,rea,reb,wea,web;
    input [ADDR-1:0] raddra, raddrb;
    input [ADDR-1:0] waddra, waddrb;
    input [WIDTH-1:0] wia, wib;
    output logic [WIDTH-1:0] doa,dob;
    reg [WIDTH-1:0] ram [DEPTH-1:0]/*verilator public*/;
    generate
        for(genvar i = 0; i< DEPTH; i++) begin
            initial ram[i] = WIDTH'(OFS + (i * INCR));
        end
    endgenerate 
    
    logic [ADDR-1:0] addra, addrb;
    logic ena, enb;
    assign addra = wea ? waddra : raddra;
    assign addrb = web ? waddrb : raddrb;
    assign ena = rea || wea;
    assign enb = reb || web;

    always @(posedge clk)
    begin
        if (ena)
        begin
            if (wea) begin
                ram[addra] <= wia;
                doa <= wia;
            end else doa <= ram[addra];
        end
    end

    always @(posedge clk)
    begin
        if (enb)
        begin
            if (web) begin
                ram[addrb] <= wib;
                dob <= wib;
            end else dob <= ram[addrb];
        end
    end
endmodule 


