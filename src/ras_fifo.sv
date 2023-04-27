module ras_fifo (clk, rst, push, pop, empty, din, dout);
    parameter DEPTH = 1024;
    parameter WIDTH = 36;
    localparam ADDR = $clog2(DEPTH);
    input clk, rst, push, pop;
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
            empty <= 1'b1;
        end else begin
            if (push) begin
                waddr <= waddr + 1'b1;
                ram[waddr] <= din;
            end
            if (pop) raddr <= raddr + 1'b1;
            if (pop ^ push) empty <= (pop && (raddr + 1'b1 == waddr));
        end
    end
    assign dout = empty ? din : ram[raddr];
    
endmodule

