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

module bram (clk,rea,reb,wea,web,raddra,raddrb,waddra,waddrb,wia,wib,ria,rib,doa,dob,rsta,rstb);
    parameter DEPTH = 1024;
    parameter WIDTH = 36;
    parameter ADDR = 10;
    parameter OFS = 0;
    parameter INCR = 0;
    input clk,rea,reb,wea,web,rsta,rstb;
    input [ADDR-1:0] raddra, raddrb;
    input [ADDR-1:0] waddra, waddrb;
    input [WIDTH-1:0] wia, wib;
    input [WIDTH-1:0] ria, rib;
    output logic [WIDTH-1:0] doa,dob;
    reg [WIDTH-1:0] ram [DEPTH-1:0]/*verilator public*/;
    generate
        for(genvar i = 0; i< DEPTH; i++) begin
            initial ram[i] = WIDTH'(OFS + (i * INCR));
        end
    endgenerate 
    
    always @(posedge clk)
    begin
        if (rea)
            doa <= ram[raddra];
        else if (wea) begin
            ram[waddra] <= wia;
            doa <= wia;
        end else if(rsta)
            doa <= ria;
    end

    always @(posedge clk)
    begin
        if (reb)
            dob <= ram[raddrb];
        else if (web) begin
            ram[waddrb] <= wib;
            dob <= wib;
        end else if(rstb)
            dob <= rib;
    end
endmodule 


