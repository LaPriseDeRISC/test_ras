
module ras (
    clk, rst_ni,
    pop, push,
    commit_pop, commit_push,
    isolate_pop, isolate_push,
    flush,
    din, dout, empty);
    parameter WIDTH = 32;
    parameter DEPTH = 1024;
    localparam ADDR = $clog2(DEPTH);
    parameter MAX_BRANCHES = 16;
    localparam MAX_BRANCHES_ADDR = $clog2(MAX_BRANCHES);
    /* verilator lint_off UNUSEDSIGNAL */
    input logic  clk, rst_ni, flush;
    input logic  pop, push;
    input logic  commit_pop, commit_push;
    input logic  isolate_pop, isolate_push;
    input logic [WIDTH-1:0] din;
    output logic [WIDTH-1:0] dout;
    output logic empty;
    /* verilator lint_on UNUSEDSIGNAL */

    logic                           reset, dout_temp_select, dout_final_select, get_from_fifo;
    logic                           buf_out_empty, branch_prev_invalid;
    logic [ADDR-1:0]                commit_tosp, tosp, tosp_n, bosp;
    logic [WIDTH-1:0]               dout_final, dout_final_out, dout_final_in;
    logic [WIDTH-1:0]               dout_temp,  dout_temp_out,  dout_temp_in;
    logic [WIDTH-1:0]               branch_prev_din, branch_din;
    logic [ADDR-1:0]                branch_prev_tosp, branch_tosp;
    logic [MAX_BRANCHES_ADDR-1:0]   pending_push_visible, pending_push_masked;
    assign empty = (tosp == bosp);

    always_comb begin
        if(reset)       tosp_n = ADDR'(0);
        else if (flush) tosp_n = commit_tosp;
        else if ((isolate_pop || isolate_push) && !branch_prev_invalid) // clear this fifo
                        tosp_n = branch_prev_tosp;
        else            tosp_n = tosp - ADDR'(pop) + ADDR'(push);
    end

    always_ff @(posedge clk or negedge rst_ni) if(!rst_ni) reset <= 1'b1;
                                               else reset <= 1'b0;
    always_ff @(posedge clk) begin
        if(reset)                           bosp <= ADDR'(0);
        else if(pop && empty)               bosp <= bosp - ADDR'(1); // underflow
        else if(push && (tosp_n == bosp))   bosp <= bosp + ADDR'(1); // overflow
    end
    always_ff @(posedge clk) tosp <= tosp_n;

    always_ff @(posedge clk) begin
        if(reset)                           commit_tosp <= ADDR'(0);
        else if(commit_push || commit_pop)  commit_tosp <= branch_tosp;
    end

    always_ff @(posedge clk) begin
        if(flush || reset || isolate_pop || isolate_push)
                                    pending_push_masked <=  '0;
        else pending_push_masked <= pending_push_masked
                                    + MAX_BRANCHES_ADDR'(pop && (pending_push_visible != 0))
                                    - MAX_BRANCHES_ADDR'((pending_push_masked != 0) && commit_push);
    end

    always_ff @(posedge clk) begin
        if(flush || reset || isolate_pop)
                                     pending_push_visible <=  '0;
        else if(isolate_push)        pending_push_visible <=  MAX_BRANCHES_ADDR'(1);
        else pending_push_visible <= pending_push_visible
                                    + MAX_BRANCHES_ADDR'(push)
                                    - MAX_BRANCHES_ADDR'(pop && (pending_push_visible != 0))
                                    - MAX_BRANCHES_ADDR'((pending_push_masked == 0) && commit_push);
    end

    /* verilator lint_off PINCONNECTEMPTY */
    ras_fifo #(.DEPTH(MAX_BRANCHES), .WIDTH(WIDTH + ADDR))
        pending_actions(.clk(clk),
            .rst(flush || reset || isolate_push || isolate_pop),
            .push((push || pop) && (!buf_out_empty)), // out buffer is full, start storing there
            .pop(get_from_fifo), // out buffer frees
            .empty(branch_prev_invalid),
            .din({din, tosp_n}),
            .dout({branch_prev_din, branch_prev_tosp}));

    assign get_from_fifo = (buf_out_empty || commit_push || commit_pop) && // we have room
                           (!branch_prev_invalid);                            // and fifo is valid

    always_ff @(posedge clk) begin
        if(flush || reset) begin
            buf_out_empty <= 1'b1;
        end else if (get_from_fifo) begin // get from fifo
            buf_out_empty <= 1'b0;
            branch_din <= branch_prev_din;
            branch_tosp <= branch_prev_tosp;
        end else if(buf_out_empty) begin // refill from din
            buf_out_empty <= !(push || pop);
            branch_din <= din;
            branch_tosp <= tosp_n;
        end else if(commit_push || commit_pop) begin
            buf_out_empty <= 1'b1; // this means we are going empty
        end
    end

    ras_bram #(.DEPTH(MAX_BRANCHES), .WIDTH(WIDTH))
        pending_data(.clk(clk),
            .doa(dout_temp_out), .wia(), .raddra(MAX_BRANCHES_ADDR'(tosp_n)), .waddra(), .rea(!push), .wea(1'b0),
            .wib(din), .dob(dout_temp_in), .raddrb(), .waddrb(MAX_BRANCHES_ADDR'(tosp_n)), .reb(1'b0), .web(push));
    always_ff @(posedge clk) dout_temp_select <= push;
    assign dout_temp = dout_temp_select ? dout_temp_in : dout_temp_out;

    ras_bram #(.DEPTH(DEPTH), .WIDTH(WIDTH))
        data(.clk(clk),
            .doa(dout_final_out), .wia(), .raddra(tosp_n), .waddra(), .rea(!((branch_tosp == tosp_n) && commit_push)), .wea(1'b0),
            .wib(branch_din), .dob(dout_final_in), .raddrb(), .waddrb(branch_tosp), .reb(1'b0), .web(commit_push));
    /* verilator lint_on PINCONNECTEMPTY */
    always_ff @(posedge clk) dout_final_select <= ((branch_tosp == tosp_n) && commit_push);
    assign dout_final = dout_final_select ? dout_final_in : dout_final_out;


    assign dout = (pending_push_visible != 0) ? dout_temp : dout_final;

endmodule : ras
