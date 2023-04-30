
module ras (
    clk, rst_ni,
    pop, push,
    commit,
    flush,
    din, dout, empty);
    parameter STAGES = 2;
    parameter WIDTH = 32;
    parameter DEPTH = 1024;
    localparam ADDR = $clog2(DEPTH);
    parameter MAX_BRANCHES = 16;
    /* verilator lint_off UNUSEDSIGNAL */
    input logic  clk, rst_ni;
    input logic  pop, push;
    input logic [STAGES-1:0] commit;
    input logic [STAGES-1:0] flush;
    input logic [WIDTH-1:0] din;
    output logic [WIDTH-1:0] dout;
    output logic empty;
    /* verilator lint_on UNUSEDSIGNAL */

    logic                           reset;
    /* verilator lint_off UNOPTFLAT */
    logic [ADDR-1:0]                tosp, tosp_n, bosp;
    /* verilator lint_on UNOPTFLAT */

    wire [STAGES:0]            stage_push;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [STAGES:0]            stage_pop;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [STAGES:0][WIDTH-1:0] stage_data;
    wire [STAGES:0][ADDR-1:0]  stage_addr;
    wire [STAGES:0][ADDR-1:0]  stage_base_addr;
    wire [STAGES:0][WIDTH-1:0] stage_dout;
    wire [STAGES-1:0]          stage_dout_valid;
    wire [STAGES:0]            trigger = {commit, pop || push};

    always_ff @(posedge clk or negedge rst_ni) if(!rst_ni) reset <= 1'b1;
                                               else reset <= 1'b0;

    always_comb begin
        tosp_n = tosp - ADDR'(pop) + ADDR'(push);
        for (int i = 0; i < STAGES ; i++)
            if(flush[i]) tosp_n = stage_base_addr[i+1];
        if(reset)        tosp_n = ADDR'(0);
    end

    always_ff @(posedge clk) tosp <= tosp_n;

    always_ff @(posedge clk) begin
        if(reset)                           bosp <= ADDR'(0);
        else if(pop && empty)               bosp <= bosp - ADDR'(1); // underflow
        else if(push && (tosp_n == bosp))   bosp <= bosp + ADDR'(1); // overflow
    end

    assign empty = (tosp == bosp);

    assign stage_push[0] = push;
    assign stage_pop[0] = pop;
    assign stage_addr[0] = tosp_n;
    assign stage_data[0] = din;

    for (genvar i = 0; i < STAGES; i++) begin
        ras_stage #(.DEPTH(MAX_BRANCHES), .WIDTH(WIDTH), .ADDR_WIDTH(ADDR))
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
        base_addr = base_addr_reg;
        if(trigger[STAGES]) base_addr = stage_addr[STAGES];
    end
    always_ff @(posedge clk) base_addr_reg <= base_addr;

    assign stage_base_addr[STAGES] = base_addr;

    /* verilator lint_off PINCONNECTEMPTY */
    ras_bram #(.DEPTH(DEPTH), .WIDTH(WIDTH), .RESOLVE_COLLIDE(1))
        data(.clk(clk),
            .doa(    stage_dout[STAGES] ), .wia(        ),
            .raddra( tosp_n             ), .waddra(     ),
            .rea(    1'b1               ), .wea(   1'b0 ),

            .dob(),          .wib(    stage_data[STAGES]                    ),
            .raddrb(),       .waddrb( stage_addr[STAGES]                    ),
            .reb(    1'b0 ), .web(    stage_push[STAGES] && trigger[STAGES] ));
    /* verilator lint_on PINCONNECTEMPTY */

    always_comb begin
        dout = stage_dout[STAGES];
        for (int i = STAGES - 1; i >= 0 ; i--)
            if(stage_dout_valid[i]) dout = stage_dout[i];
    end

endmodule : ras
