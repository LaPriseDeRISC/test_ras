
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

    logic                           reset;
    /* verilator lint_off UNOPTFLAT */
    logic [ADDR-1:0]                tosp, tosp_n, empty_start, last_addr;
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
    NOT IMPLEMENTED YET
    `else
    initial empty_start =   ADDR'(1);
    initial last_addr =     ADDR'(-1);
    always @(posedge clk) last_addr <=   tosp_n - 1;
    always @(posedge clk) empty_start <= tosp_n + 1;
    `endif

    initial reset = 1;
    always @(posedge clk or negedge rst_ni) if(!rst_ni) reset <= 1'b1;
                                            else        reset <= rst_i;

    always_comb begin
        tosp_n = tosp;
        if(!reset) begin
            if(pop && !push) tosp_n = last_addr;
            if(push && !pop) tosp_n = empty_start;
            //tosp_n = tosp - ADDR'(pop) + ADDR'(push);
            for (int i = 0; i < STAGES ; i++)
                if(flush[i]) tosp_n = stage_base_addr[i+1];
        end
    end

    initial               tosp = ADDR'(0);
    always @(posedge clk) tosp <= tosp_n;

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


    logic [ADDR-1:0] base_addr_reg, base_addr;
    always_comb begin
        if(trigger[STAGES]) base_addr = stage_addr[STAGES];
        else base_addr = base_addr_reg;
    end

    always_ff @(posedge clk) begin
        if(reset) base_addr_reg <= ADDR'(0);
        else      base_addr_reg <= base_addr;
    end

    assign stage_base_addr[STAGES] = base_addr;

    /* verilator lint_off PINCONNECTEMPTY */
    ras_bram #(.DEPTH(DEPTH), .WIDTH(WIDTH + 1), .RESOLVE_COLLIDE(1))
        data(.clk(clk),
            .doa(    {stage_dout[STAGES], stage_dout_valid[STAGES]} ), .wia(        ),
            .raddra( tosp_n             ), .waddra(     ),
            .rea(    1'b1               ), .wea(   1'b0 ),

            .dob(),          .wib( { stage_data[STAGES], stage_push[STAGES] }),
            .raddrb(),       .waddrb( stage_push[STAGES] ? stage_addr[STAGES] : base_addr_reg),
            .reb(    1'b0 ), .web(    trigger[STAGES] ));
    /* verilator lint_on PINCONNECTEMPTY */

    always_comb begin
        dout = stage_dout[STAGES];
        for (int i = STAGES - 1; i >= 0 ; i--)
            if(stage_dout_valid[i]) dout = stage_dout[i];
        valid = (|stage_dout_valid);
    end

endmodule : ras
