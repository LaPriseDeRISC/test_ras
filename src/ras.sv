
module ras (
    clk, rst_ni, rst_i,
    pop, push,
    commit,
    flush,
    din, dout, valid);
    parameter STAGES = 2;
    parameter WIDTH = 31;
    parameter DEPTH = 1024;
    localparam ADDR = $clog2(DEPTH);
    parameter SCRATCHPAD_DEPTH = 16;
    localparam SCRATCHPAD_ADDR = $clog2(SCRATCHPAD_DEPTH);
    /* verilator lint_off UNUSEDSIGNAL */
    input logic  clk, rst_ni, rst_i;
    input logic  pop, push;
    input logic [STAGES-1:0] commit;
    input logic [STAGES-1:0] flush;
    input logic [WIDTH-1:0] din;
    output logic [WIDTH-1:0] dout;
    output logic valid;
    /* verilator lint_on UNUSEDSIGNAL */

    logic                           reset, incr, decr, set_tosp, empty, full;
    /* verilator lint_off UNOPTFLAT */
    logic [ADDR-1:0]                new_tosp, tosp_n, bosp, base_addr;
    /* verilator lint_on UNOPTFLAT */

    wire [STAGES:0]            stage_push;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [STAGES:0]            stage_pop;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [STAGES:0][WIDTH-1:0] stage_data;
    wire [STAGES:0][ADDR-1:0]  stage_addr;
    wire [STAGES:0][ADDR-1:0]  stage_base_addr;
    wire [STAGES:0][WIDTH-1:0] stage_dout;
    wire [STAGES:0]            stage_dout_valid;
    wire [STAGES:0]            trigger = {commit, pop || push};

    `ifdef RAS_LINKED

    `else
    logic [ADDR-1:0] tosp;
    initial               tosp = ADDR'(0);
    always @(posedge clk) tosp <= tosp_n;
    always_comb begin
        tosp_n = tosp;
        if(decr) tosp_n = tosp - 1;
        if(incr) tosp_n = tosp + 1;
        if(set_tosp) tosp_n = new_tosp;
    end
    assign empty = ((tosp == bosp) && !full);
    `endif

    initial reset = 1;
    always @(posedge clk or negedge rst_ni) if(!rst_ni) reset <= 1'b1;
                                            else        reset <= rst_i;

    assign decr = (pop && !push && valid);
    assign incr = (push && !pop);
    assign set_tosp = (|flush) && valid;

    always_comb begin
        new_tosp = 'x;
        for (int i = 0; i < STAGES ; i++)
            if(flush[i]) new_tosp = stage_base_addr[i+1];
    end

    assign stage_push[0] = push;
    assign stage_pop[0] = pop;
    assign stage_addr[0] = tosp_n;
    assign stage_data[0] = din;

    for (genvar i = 0; i < STAGES; i++) begin
        ras_stage #(.WIDTH(WIDTH), .DEPTH(DEPTH), .SCRATCHPAD_DEPTH(SCRATCHPAD_DEPTH))
            stage(.clk(clk), .reset(flush[i] || reset),
                .trigger(trigger[i]), .commit(commit[i]),
                .pop_i(stage_pop[i]), .push_i(stage_push[i]),
                .addr_i(stage_addr[i]), .data_i(stage_data[i]),
                .pop_o(stage_pop[i+1]), .push_o(stage_push[i+1]),
                .addr_o(stage_addr[i+1]), .data_o(stage_data[i+1]),
                .addr(tosp_n), .dout(stage_dout[i]), .valid(stage_dout_valid[i]),
                .base_addr(stage_base_addr[i]));
    end

    always_ff @(posedge clk) begin
        if(reset) begin
             full <= 1'b0;
             bosp <= tosp_n;
        end else if(incr) begin
            full <= ((tosp_n == bosp) || full);
            if(full) bosp <= tosp_n;
        end else if (decr) full <= 1'b0;
    end
    assign stage_dout_valid[STAGES] = !empty;


    always_ff @(posedge clk) if(trigger[STAGES]) base_addr <= stage_addr[STAGES];
    assign stage_base_addr[STAGES] = base_addr;


    /* verilator lint_off PINCONNECTEMPTY */
    ras_bram #(.DEPTH(DEPTH), .WIDTH(WIDTH), .RESOLVE_COLLIDE(1))
        data(.clk(clk),
            .doa(    stage_dout[STAGES] ),  .wia( ),
            .raddra( tosp_n ),              .waddra( ),
            .rea(    1'b1 ),                .wea( 1'b0 ),

            .dob( ),          .wib( stage_data[STAGES] ),
            .raddrb( ),       .waddrb( stage_addr[STAGES] ),
            .reb( 1'b0 ), .web( trigger[STAGES] && stage_push[STAGES] ));
    /* verilator lint_on PINCONNECTEMPTY */

    always_comb begin
        dout = 'x;
        for (int i = STAGES; i >= 0 ; i--)
            if(stage_dout_valid[i]) dout = stage_dout[i];
    end

    assign valid = (|stage_dout_valid);

endmodule : ras
