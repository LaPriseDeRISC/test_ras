
module ras_stage (
    clk, reset,
    pop_i, push_i, data_i, addr_i,
    pop_o, push_o, data_o, addr_o,
    trigger, commit,
    base_addr, addr, dout, valid);

    parameter DEPTH = 16;
    localparam ADDR = $clog2(DEPTH);
    parameter WIDTH = 32;
    parameter ADDR_WIDTH = 10;

    input logic clk, reset, trigger, commit;
    input logic pop_i, push_i;
    input logic [ADDR_WIDTH-1:0] addr_i;
    input logic [WIDTH-1:0] data_i;
    output logic pop_o, push_o;
    output logic [ADDR_WIDTH-1:0] addr_o;
    output logic [WIDTH-1:0] data_o;
    input logic [ADDR_WIDTH-1:0] addr;
    output logic [ADDR_WIDTH-1:0] base_addr;
    output logic [WIDTH-1:0] dout;
    output logic valid;

    logic [ADDR-1:0] pending_push_masked, pending_push_visible;
    logic [ADDR-1:0] base_addr_reg;

    assign valid = (pending_push_visible != 0);

    /* verilator lint_off PINCONNECTEMPTY */
    ras_bram #(.DEPTH(DEPTH), .WIDTH(WIDTH), .RESOLVE_COLLIDE(1))
        scratchpad(.clk(clk),
            .doa(    dout        ), .wia(       ),
            .raddra( ADDR'(addr) ), .waddra(    ),
            .rea(    1'b1        ), .wea(   1'b0),

            .dob(),          .wib(    data_i            ),
            .raddrb(),       .waddrb( ADDR'(addr_i)     ),
            .reb(    1'b0 ), .web(    trigger && push_i ));
    /* verilator lint_on PINCONNECTEMPTY */

    always_ff @(posedge clk) begin
        if(reset)                    pending_push_masked <=  '0;
        else pending_push_masked <=  pending_push_masked
                                    + ADDR'(pop_i && trigger && (pending_push_visible != 0))
                                    - ADDR'((pending_push_masked != 0) && commit && push_o);
    end

    always_ff @(posedge clk) begin
        if(reset)                    pending_push_visible <=  '0;
        else pending_push_visible <= pending_push_visible
                                    + ADDR'(trigger && push_i)
                                    - ADDR'(trigger && pop_i && (pending_push_visible != 0))
                                    - ADDR'((pending_push_masked == 0) && commit && push_o);
    end

    always_comb begin
        base_addr = base_addr_reg;
        if(trigger) base_addr = addr_i;
    end

    always_ff @(posedge clk) begin
        if(reset) base_addr_reg <= addr;
        else      base_addr_reg <= base_addr;
    end

    /* verilator lint_off PINCONNECTEMPTY */
    ras_fifo #(.DEPTH(DEPTH), .WIDTH(WIDTH + ADDR_WIDTH + 1 + 1))
        pending_actions(.clk(clk),
            .rst(reset),
            .push(trigger),
            .pop(commit),
            .empty(),
            .din( {data_i, addr_i, pop_i, push_i}),
            .dout({data_o, addr_o, pop_o, push_o}));
    /* verilator lint_on PINCONNECTEMPTY */
endmodule : ras_stage
