`timescale 1ns / 1ps

module ras (
    clk, reset, pop, push, branch,
    close_valid, close_invalid,
    din, dout, busy, empty);
    parameter WIDTH = 32;
    parameter ADDR = 4;
    parameter DEPTH = 16;
    parameter DIRECTION = 1;
    parameter INITIAL_ADDR = 0;
    /* verilator lint_off UNUSEDSIGNAL */
    input logic clk, reset, pop, push, branch, close_valid, close_invalid;
    input logic [WIDTH-1:0] din;
    output logic [WIDTH-1:0] dout;
    output logic busy, empty;
    /* verilator lint_on UNUSEDSIGNAL */

    assign busy = 1'b0;
    assign empty = (prev_tosp == bosp);

    logic in_branch/*verilator public*/, on_branch/*verilator public*/;
    logic consume_tosp, consume_empty, clear_tosp;
    logic attach_vector;

    assign on_branch = in_branch && (tosp == branch_tosp) && !(close_valid || close_invalid);
    assign clear_tosp = pop && !on_branch && !push;
    assign consume_tosp = pop && !(push && !on_branch);
    assign consume_empty = push && !(pop && !on_branch);
    assign branch_has_suppressed = branch_tosp != branch_initial_tosp;
    assign attach_vector = close_valid && in_branch && branch_has_suppressed;

    logic [ADDR-1 : 0] tosp/*verilator public*/, tosp_n, bosp/*verilator public*/;
    logic [ADDR-1 : 0] empty_start/*verilator public*/, empty_start_n;
    logic [ADDR-1 : 0] empty_next/*verilator public*/, empty_next_out, empty_next_temp;
    logic [ADDR-1 : 0] prev_tosp/*verilator public*/;

    logic [ADDR-1 : 0] branch_tosp/*verilator public*/, branch_initial_empty_start/*verilator public*/;
    logic [ADDR-1 : 0] branch_initial_tosp/*verilator public*/, branch_empty_start/*verilator public*/, branch_empty_next/*verilator public*/;
    logic branch_has_suppressed/*verilator public*/;

    logic [ADDR-1 : 0] branch_tosp_2, branch_initial_empty_start_2;
    logic attach_vector_2, attach_vector_3, empty_next_is_branch_initial_empty;

    initial tosp = ADDR'(INITIAL_ADDR);
    initial empty_start = ADDR'(INITIAL_ADDR + DIRECTION);
    initial bosp = ADDR'(INITIAL_ADDR - DIRECTION);

    always_ff @(posedge clk) begin
        if(branch) begin
            in_branch <= 1'b1;
            branch_tosp <= tosp;
            branch_initial_empty_start <= empty_start;
            branch_initial_tosp <= tosp;
        end else if(close_valid || close_invalid)
            in_branch <= 1'b0;
    end

    always_ff @(posedge clk) begin
        if(on_branch && pop) begin
            branch_tosp <= prev_tosp;
            branch_empty_start <= tosp;
            branch_empty_next <= empty_start;
        end
    end

    always_comb begin
        if(consume_empty)
            tosp_n = empty_start;
        else if(consume_tosp)
            tosp_n = prev_tosp;
        else if(close_invalid)
            tosp_n = branch_initial_tosp;
        else tosp_n = tosp;
    end

    always_ff @(posedge clk) tosp <= tosp_n;

    always_comb begin
        if(consume_empty)
            empty_start_n = attach_vector ? branch_empty_start : empty_next;
        else if(clear_tosp)
            empty_start_n = tosp;
        else if(close_invalid)
            empty_start_n = branch_initial_empty_start;
        else empty_start_n = empty_start;
    end

    always_ff @(posedge clk) empty_start <= empty_start_n;

    always_ff @(posedge clk) begin
        attach_vector_2 <= attach_vector;
        attach_vector_3 <= attach_vector_2;
        if(attach_vector) begin
            branch_tosp_2 <= branch_tosp;
            branch_initial_empty_start_2 <= branch_initial_empty_start;
            if(consume_empty)
                if(branch_empty_next == branch_initial_empty_start) //vector size is one
                    empty_next_temp <= empty_next;
                else
                    empty_next_temp <= branch_empty_next; //vector size is more
            else if(clear_tosp) begin
                empty_next_temp <= empty_start;
            end else
                empty_next_temp <= branch_empty_start;
        end
    end
    // on second clock of closing vector, if empty_start == branch_tosp_2
    // it means that the link with its next free (branch_initial_empty_start_2) is not yet written
    assign empty_next_is_branch_initial_empty = attach_vector_3 && (empty_start == branch_tosp_2);
    assign empty_next = attach_vector_2 ? empty_next_temp :
        (empty_next_is_branch_initial_empty ? branch_initial_empty_start_2 : empty_next_out);

    /* verilator lint_off PINCONNECTEMPTY */
    bram #(.DEPTH(DEPTH), .WIDTH(ADDR), .ADDR(ADDR), .OFS(DIRECTION), .INCR(1))
        free_data(.clk(clk),
            .doa(empty_next_out),
            .raddra(empty_start_n),                                 .rea(~attach_vector),
            .waddra(empty_start), .wia(branch_empty_start),         .wea(attach_vector),
            .ria(),                                                 .rsta(1'b0),
            .dob(),
            .raddrb(),                                              .reb(1'b0),
            .waddrb(attach_vector ? branch_initial_tosp : branch_tosp_2),
                    .wib(attach_vector ? empty_next : branch_initial_empty_start_2),
                                                                    .web(attach_vector || attach_vector_2),
            .rib(),                                                 .rstb(1'b0)
        );
    
    bram #(.DEPTH(DEPTH), .WIDTH(ADDR), .ADDR(ADDR), .OFS(-DIRECTION), .INCR(1))
        used_data(.clk(clk),
            .doa(prev_tosp),
            .raddra(tosp_n),                                        .rea(~consume_empty),
            .waddra(tosp_n),
                .wia((pop && on_branch) ? prev_tosp : tosp),     .wea(consume_empty),
            .ria(),                                                 .rsta(1'b0),
            .dob(),
            .raddrb(),                                              .reb(1'b0),
            .waddrb(), .wib(),                                      .web(1'b0),
            .rib(),                                                 .rstb(1'b0)
        );

    bram #(.DEPTH(DEPTH), .WIDTH(32), .ADDR(ADDR))
        data(.clk(clk),
            .doa(dout), .wia(), .ria(), .raddra(tosp), .waddra(), .rea(pop), .wea(1'b0), .rsta(1'b0),
            .wib(din), .dob(), .rib(), .raddrb(), .waddrb(tosp_n), .reb(1'b0), .web(push), .rstb(1'b0));

    /* verilator lint_on PINCONNECTEMPTY */
endmodule : ras
