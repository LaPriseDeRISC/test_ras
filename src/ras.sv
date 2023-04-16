`timescale 1ns / 1ps


// branches fifo overflow is critical
// branches "valid_close" need two cycles in some conditions
// when two branches following have suppressed elements
// in the case of an in-order CPU this should not matter

module ras (
    clk, reset, pop, push, branch,
    close_valid, close_invalid,
    din, dout, empty);
    parameter WIDTH = 32;
    parameter DEPTH = 1024;
    localparam ADDR = $clog2(DEPTH);
    parameter DIRECTION = 1;
    parameter INITIAL_ADDR = 0;
    parameter MAX_BRANCHES = 128;
    /* verilator lint_off UNUSEDSIGNAL */
    input logic clk, reset, pop, push, branch, close_valid, close_invalid;
    input logic [WIDTH-1:0] din;
    output logic [WIDTH-1:0] dout;
    output logic empty;
    /* verilator lint_on UNUSEDSIGNAL */

    assign empty = (tosp == bosp);

    logic branch_list_empty;
    logic in_branch/*verilator public*/, on_branch/*verilator public*/;
    logic consume_tosp, consume_empty, clear_tosp;
    logic attach_vector;
    logic do_pop;
    logic closing_current_branch;

    assign closing_current_branch = (close_valid && branch_list_empty);
    assign do_pop = pop && !empty;
    assign on_branch = in_branch && (tosp == current_branch_tosp) && !(close_invalid || closing_current_branch);
    assign clear_tosp = do_pop && !on_branch && !push;
    assign consume_tosp = do_pop && !(push && !on_branch);
    assign consume_empty = push && !(do_pop && !on_branch);
    // we could store that in the fifo and add a nice counter to save some space
    assign branch_has_suppressed = branch_tosp != branch_initial_tosp;
    assign attach_vector = close_valid && in_branch && branch_has_suppressed;

    logic [ADDR-1 : 0] tosp/*verilator public*/, tosp_n, bosp/*verilator public*/;
    logic [ADDR-1 : 0] empty_start/*verilator public*/, empty_start_n;
    logic [ADDR-1 : 0] empty_next/*verilator public*/, empty_next_out, empty_next_temp;
    logic [ADDR-1 : 0] prev_tosp/*verilator public*/;

    logic [ADDR-1 : 0] branch_tosp/*verilator public*/, branch_initial_empty_start/*verilator public*/;
    logic [ADDR-1 : 0] branch_initial_tosp/*verilator public*/, branch_empty_start/*verilator public*/, branch_empty_next/*verilator public*/;
    logic [ADDR-1 : 0] current_branch_initial_tosp, current_branch_initial_empty_start,
                                   current_branch_tosp, current_branch_empty_start, current_branch_empty_next;
    logic branch_has_suppressed/*verilator public*/;

    logic [ADDR-1 : 0] branch_tosp_2, branch_initial_empty_start_2;
    logic attach_vector_2, attach_vector_3, empty_next_is_branch_initial_empty;

    initial tosp = ADDR'(INITIAL_ADDR);
    initial empty_start = ADDR'(INITIAL_ADDR + DIRECTION);
    initial bosp = ADDR'(INITIAL_ADDR);

    // in_branch flag process
    always_ff @(posedge clk) begin
        if(close_invalid)
            in_branch <= 1'b0;
        else if(branch)
            in_branch <= 1'b1;
        else if(closing_current_branch)
            in_branch <= 1'b0;
    end

    // current branch pointers process
    always_ff @(posedge clk) begin
        if(branch) begin
            current_branch_tosp <= tosp_n;
            current_branch_empty_start <= empty_start_n;
            current_branch_initial_tosp <= tosp_n;
            current_branch_initial_empty_start <= empty_start_n;
        end else if(on_branch && do_pop) begin
            current_branch_tosp <= prev_tosp;
            current_branch_empty_start <= tosp;
            current_branch_empty_next <= current_branch_empty_start;
        end
    end

    // bosp overflow process
    always_ff @(posedge clk) if(consume_empty && empty_start == bosp) bosp <= empty_next;
    // bosp represents the entry point in the linked list
    // [tosp :>> bosp[ is where the data is stored
    // [empty_start <<: bosp] are the free slots
    // ( :>> (used_data) / <<: (free_data) means the direction of the linkage)
    // an element is lost when he is overflown in the "free slots"
    // we use empty_next in case of an "attach_vector" condition

    // next tosp calculation
    always_comb begin
        if(consume_empty)
            tosp_n = empty_start;
        else if(consume_tosp)
            tosp_n = prev_tosp;
        else if(close_invalid)
            tosp_n = branch_initial_tosp;
        else tosp_n = tosp;
    end

    // tosp update process
    always_ff @(posedge clk) tosp <= tosp_n;

    // next empty_start calculation
    always_comb begin
        if(consume_empty)
            empty_start_n = attach_vector ? branch_empty_start : empty_next;
        else if(clear_tosp)
            empty_start_n = tosp;
        else if(close_invalid)
            empty_start_n = branch_initial_empty_start;
        else empty_start_n = empty_start;
    end

    // empty_start update process
    always_ff @(posedge clk) empty_start <= empty_start_n;

    // two-clock vector move process
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

    // empty_next source selection
    assign empty_next = attach_vector_2 ? empty_next_temp :
        (empty_next_is_branch_initial_empty ? branch_initial_empty_start_2 : empty_next_out);

    /* verilator lint_off PINCONNECTEMPTY */
    // free data ([empty_start <<: bosp]) links generator
    // these links must always valid (excepted in the two-clock process)
    // memory initialization is needed: mem[i] = (i * INCR) + OFS
    // we need 3 memory accesses to move a vector, hence the two-clock process
    bram #(.DEPTH(DEPTH), .WIDTH(ADDR), .OFS(DIRECTION), .INCR(1))
        free_data(.clk(clk),
            .doa(empty_next_out),
            .raddra(empty_start_n),                                 .rea(~attach_vector),
            .waddra(empty_start), .wia(branch_empty_start),         .wea(attach_vector),
            .ria(),                                                 .rsta(1'b0),
            .dob(),
            .raddrb(),                                              .reb(1'b0),
            .waddrb(attach_vector ? branch_initial_tosp : branch_tosp_2),
               .wib(attach_vector ? empty_next          : branch_initial_empty_start_2),
                                                                    .web(attach_vector || attach_vector_2),
            .rib(),                                                 .rstb(1'b0)
        );

    // used data links generator
    // links are valid only inside [tosp :>> bosp[
    // no initialization needed
    bram #(.DEPTH(DEPTH), .WIDTH(ADDR))
        used_data(.clk(clk),
            .doa(prev_tosp),
            .raddra(tosp_n),                                        .rea(~consume_empty),
            .waddra(tosp_n), .wia(consume_tosp ? prev_tosp : tosp), .wea(consume_empty),
            .ria(),                                                 .rsta(1'b0),
            .dob(),
            .raddrb(),                                              .reb(1'b0),
            .waddrb(), .wib(),                                      .web(1'b0),
            .rib(),                                                 .rstb(1'b0)
        );

    bram #(.DEPTH(DEPTH), .WIDTH(32))
        data(.clk(clk),
            .doa(dout), .wia(), .ria(), .raddra(tosp), .waddra(), .rea(do_pop), .wea(1'b0), .rsta(1'b0),
            .wib(din), .dob(), .rib(), .raddrb(), .waddrb(tosp_n), .reb(1'b0), .web(push), .rstb(1'b0));

    fifo #(.DEPTH(MAX_BRANCHES), .WIDTH(5 * ADDR))
        branches(.clk(clk), .rst(close_invalid),
            .push(branch && in_branch && !closing_current_branch),
            .pop(close_valid && !branch_list_empty),
            .empty(branch_list_empty),
            .din({current_branch_initial_tosp, current_branch_initial_empty_start,
            current_branch_tosp, current_branch_empty_start, current_branch_empty_next}),
            .dout({branch_initial_tosp, branch_initial_empty_start, branch_tosp, branch_empty_start, branch_empty_next}));
    /* verilator lint_on PINCONNECTEMPTY */
endmodule : ras
