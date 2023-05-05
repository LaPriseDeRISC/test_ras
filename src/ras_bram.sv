
module ras_bram (clk,rea,reb,wea,web,raddra,raddrb,waddra,waddrb,wia,wib,doa,dob);
    parameter DEPTH = 1024;
    parameter WIDTH = 36;
    localparam ADDR = $clog2(DEPTH);
    parameter RESOLVE_COLLIDE = 0;
    parameter OFS = 0;
    parameter INCR = 0;
    input clk,rea,reb,wea,web;
    input [ADDR-1:0] raddra, raddrb;
    input [ADDR-1:0] waddra, waddrb;
    input [WIDTH-1:0] wia, wib;
    output logic [WIDTH-1:0] doa,dob;

    logic forward_a, forward_b;
    wire [ADDR-1:0] addra = wea ? waddra : raddra;
    wire [ADDR-1:0] addrb = web ? waddrb : raddrb;
    wire collision = RESOLVE_COLLIDE && (addra == addrb) && (rea || wea) && (reb || web);
    wire forward_a_n = collision && web;
    wire forward_b_n = collision && wea;
    wire ena = (rea || wea) && !forward_a_n;
    wire enb = (reb || web) && !forward_b_n;
    logic [WIDTH-1:0] ram_out_a, ram_out_b;

    assign doa = forward_a ? ram_out_b : ram_out_a;
    assign dob = forward_b ? ram_out_a : ram_out_b;

    always_ff @(posedge clk) begin
        forward_a <= forward_a_n;
        forward_b <= forward_b_n;
    end
    
    bram_impl #(.DEPTH(DEPTH), .WIDTH(WIDTH), .OFS(OFS), .INCR(INCR))
        data (
        .clk(clk), .ena(ena), .enb(enb),
        .wea(wea), .web(web),
        .addra(addra), .addrb(addrb),
        .wia(wia), .wib(wib),
        .doa(ram_out_a), .dob(ram_out_b)
    );
endmodule 
    
/* verilator lint_off DECLFILENAME */
module bram_impl (clk,ena,enb,wea,web,addra,addrb,wia,wib,doa,dob);
    parameter DEPTH = 1024;
    parameter WIDTH = 36;
    localparam ADDR = $clog2(DEPTH);
    parameter OFS = 0;
    parameter INCR = 0;
    input clk, ena, enb, wea, web;
    input [ADDR-1:0] addra, addrb;
    input [WIDTH-1:0] wia, wib;
    output logic [WIDTH-1:0] doa,dob;
    reg [WIDTH-1:0] ram [DEPTH-1:0]/*verilator public*/;
    for(genvar i = 0; i< DEPTH; i++) begin
        initial ram[i] = WIDTH'(OFS + (i * INCR));
    end

    initial doa = OFS;
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

    initial dob = OFS;
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
/* verilator lint_on DECLFILENAME */

