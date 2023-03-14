`timescale 1ns / 1ps

/* verilator lint_off UNUSEDSIGNAL */
module ras (clk, pop, push, branch, close_valid, close_invalid, din, dout, pop_valid);
    parameter MAXBRANCHES = 16;
    parameter BRANCHES_ADDR = 4;
    parameter DEPTH = 16;
    parameter WIDTH = 32;
    parameter ADDR = 4;
    parameter INITIAL_ADDR = 0;

    input logic clk, pop, push, branch, close_valid, close_invalid;
    input logic [WIDTH-1:0] din;
    output logic [WIDTH-1:0] dout;
    output logic pop_valid;

    logic [ADDR-1:0] BOSP/*verilator public*/;
    logic in_branch/*verilator public*/;
    logic branch_list_empty/*verilator public*/;
    logic current_branch_has_added/*verilator public*/, current_branch_has_suppressed/*verilator public*/, vector_has_suppressed;
    typedef struct packed {
        logic size_is_one, size_is_two;
        logic [ADDR-1:0] previous, head, second, third, tail, next;
    } vector_t;
    initial BOSP = ADDR'(INITIAL_ADDR-1);
    initial last_alloc_addr_ff = BOSP;

    logic empty/*verilator public*/;
        assign empty = (last_alloc_addr == BOSP);
    assign pop_valid = (pop && !empty);

    logic allocate_mem, de_alloc_mem, reset_mem, de_alloc_vec_mem, read_last_alloc;
    logic [ADDR-1:0] alloc_addr/*verilator public*/, reset_addr, last_alloc_addr/*verilator public*/, last_alloc_mem_out, last_alloc_addr_ff;

    /* verilator lint_off PINCONNECTEMPTY */

    vector_t current_branch_vector/*verilator public*/, free_vec_intf;

    memory_allocator #(.ADDR(ADDR), .DEPTH(DEPTH), .DIRECTION(1), .INITIAL_ADDR(INITIAL_ADDR))
    memory(.clk(clk),
        .alloc(allocate_mem), .de_alloc(de_alloc_mem), .reset(reset_mem), .de_alloc_vector(de_alloc_vec_mem),
        .last_alloc_addr(last_alloc_addr), .alloc_addr(alloc_addr), .reset_addr(reset_addr),
        .vec_intf(free_vec_intf));

    bram #(.DEPTH(DEPTH), .WIDTH(32), .ADDR(ADDR))
    data(.clk(clk),
        .doa(dout), .dia(), .addra(last_alloc_addr), .ena(pop), .wea(1'b0),
        .dib(din), .dob(), .addrb(allocate_mem ? alloc_addr : last_alloc_addr), .enb(push), .web(push));

    fifo #(.DEPTH(MAXBRANCHES), .WIDTH($bits(vector_t) + 1), .ADDR(BRANCHES_ADDR))
    branches(.clk(clk),
        .din({current_branch_vector, current_branch_has_suppressed}),
        .dout({free_vec_intf, vector_has_suppressed}),
        .wen((in_branch && branch_list_empty) || branch),
        .pop(((in_branch ^ branch) && branch_list_empty) || close_valid),
        .empty(branch_list_empty),
        .rst(close_invalid));

     bram #(.DEPTH(DEPTH), .WIDTH(ADDR), .ADDR(ADDR), .OFS(-1), .BLANK(0))
     next_links(.clk(clk),
        .doa(), .ena(allocate_mem),
        .dia(last_alloc_addr), .addra(alloc_addr),
        .wea(allocate_mem),
        .dob(last_alloc_mem_out), .enb(de_alloc_mem || reset_mem),
        .dib(), .addrb(reset_mem ? free_vec_intf.previous : last_alloc_addr),
        .web(1'b0)
        );

    assign last_alloc_addr = read_last_alloc ? last_alloc_mem_out : last_alloc_addr_ff;
    /* verilator lint_on PINCONNECTEMPTY */
    logic data_is_protected;
    assign data_is_protected = (in_branch && !current_branch_has_added);
    assign de_alloc_mem = pop && !data_is_protected && !push;
    assign allocate_mem = push && !(pop || data_is_protected);
    assign reset_mem = close_invalid;
    assign reset_addr = free_vec_intf.previous;
    assign de_alloc_vec_mem = close_valid && vector_has_suppressed;
    
    always_ff @(posedge clk) begin
        read_last_alloc <= de_alloc_mem || reset_mem;
        if(allocate_mem)
            last_alloc_addr_ff <= alloc_addr;
        else if(read_last_alloc)
            last_alloc_addr_ff <= last_alloc_mem_out;
        if(close_invalid)
            in_branch <= 1'b0;
        else if(branch) begin
            in_branch <= 1'b1;
            current_branch_has_added <= 1'b0;
            current_branch_has_suppressed <= 1'b0;
            current_branch_vector.size_is_one <= 1'b0;
            current_branch_vector.size_is_two <= 1'b0;
            current_branch_vector.previous <= last_alloc_addr;
            current_branch_vector.next <= alloc_addr;
        end
        else if(close_valid)
            in_branch <= !branch_list_empty;
        if(pop) begin
            if(data_is_protected) begin
                current_branch_has_suppressed <= 1'b1;
                current_branch_vector.head <= last_alloc_addr;
                current_branch_vector.size_is_one <= current_branch_has_suppressed;
                current_branch_vector.second <= current_branch_vector.head;
                current_branch_vector.size_is_two <= current_branch_vector.size_is_one;
                current_branch_vector.third <= current_branch_vector.second;
                current_branch_vector.tail <= alloc_addr;
            end else if(in_branch && current_branch_vector.previous == last_alloc_addr) begin
                current_branch_has_added <= 1'b0;
            end
        end else
        if(push && in_branch) begin
            current_branch_has_added <= 1'b1;
        end
   end
    
    
    
endmodule
/* verilator lint_on UNUSEDSIGNAL */

