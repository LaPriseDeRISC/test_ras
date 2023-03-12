`timescale 1ns / 1ps
/* verilator lint_off UNUSEDSIGNAL */
module ras (clk, pop, push, branch, close_valid, close_invalid, din, dout, pop_valid);
    parameter MAXBRANCHES = 16;
    parameter BRANCHES_ADDR = 4;
    parameter DEPTH = 16;
    parameter WIDTH = 32;
    parameter ADDR = 4;
    input logic clk, pop, push, branch, close_valid, close_invalid;
    input logic [WIDTH-1:0] din;
    output logic [WIDTH-1:0] dout;
    output logic pop_valid;
    
    logic [ADDR-1:0] BOSP/*verilator public*/;
    logic in_branch/*verilator public*/;
    logic branch_list_empty/*verilator public*/;
    logic has_added/*verilator public*/, has_one_suppressed, has_suppressed/*verilator public*/;
    logic [ADDR-1:0] pop_head/*verilator public*/, a_end/*verilator public*/,
                     s_head/*verilator public*/, s_queue/*verilator public*/, s_tail/*verilator public*/,
                     ef_start/*verilator public*/, push_head/*verilator public*/;
    logic [ADDR-1:0] ef_start_archived, a_end_archived,
                     s_head_archived, s_queue_archived, s_tail_archived,
                     has_one_suppressed_archived, has_suppressed_archived;
    logic [ADDR-1:0] pop_queue/*verilator public*/;
    
    
            
    initial BOSP = ADDR'(DEPTH - 1);
    initial pop_head = BOSP;
    initial push_head = pop_head + 1;
    initial s_head = pop_head;
    initial s_queue = s_head;
    initial s_tail = s_head;
    initial a_end = push_head;
    initial ef_start = pop_head;
    
    logic empty/*verilator public*/; 
        assign empty = (pop_head == BOSP);
    logic full/*verilator public*/; 
        assign full = (push_head == BOSP);
    assign pop_valid = (pop && !empty);
    
    logic allocate_mem, free_mem, fetch_mem, free_vec_mem;
    logic [ADDR-1:0] alloc_addr, free_addr;
    
    /* verilator lint_off PINCONNECTEMPTY */     
    
    memory_allocator #(.ADDR(ADDR), .DEPTH(DEPTH), .INITIAL_FETCH(0), .DIRECTION(1))
    memory(.clk(clk),
            .alloc(allocate_mem), .free(free_mem), .fetch(fetch_mem), .free_vector(free_vec_mem),
            .free_addr(free_addr), .alloc_addr(alloc_addr), .fetch_addr(a_end_archived),
            .vector_size_is_one(has_one_suppressed_archived), 
            .vector_start(s_head_archived), .vector_snd(s_queue_archived), .vector_end(s_tail_archived));
             
    bram #(.DEPTH(DEPTH), .WIDTH(32), .ADDR(ADDR))
    data(.clk(clk),
         .doa(dout), .dia(), .addra(free_addr), .ena(pop), .wea(1'b0),
         .dib(din), .dob(), .addrb(allocate_mem ? alloc_addr : free_addr), .enb(push), .web(push));

    fifo #(.DEPTH(MAXBRANCHES), .WIDTH(ADDR * 5 + 2), .ADDR(BRANCHES_ADDR))
    branches(.clk(clk),
             .din({ef_start, a_end, s_head, s_queue, s_tail,
                    has_one_suppressed, has_suppressed}),
             .dout({ef_start_archived, a_end_archived, s_head_archived, s_queue_archived, s_tail_archived,
                    has_one_suppressed_archived, has_suppressed_archived}),
             .wen((in_branch && branch_list_empty) || branch), 
             .pop(((in_branch ^ branch) && branch_list_empty) || close_valid),
             .empty(branch_list_empty),
             .rst(close_invalid));
     
     bram #(.DEPTH(DEPTH), .WIDTH(ADDR), .ADDR(ADDR), .OFS(-1), .BLANK(0))
     next_links(.clk(clk),
          .doa(free_addr), .ena(allocate_mem),
          .dia(free_addr), .addra(alloc_addr),
          .wea(allocate_mem),
          .dob(), .enb(1'b0),
          .dib(), .addrb(), 
          .web(1'b0)
          );
    
   /* verilator lint_on PINCONNECTEMPTY */
   logic data_is_protected;
   assign data_is_protected = (in_branch && !has_added);
   assign free_mem = pop && !data_is_protected && !push;
   assign allocate_mem = push && !(pop || data_is_protected);
   assign fetch_mem = close_invalid;
   assign free_vec_mem = close_valid && has_suppressed_archived;
    
   always_ff @(posedge clk) begin
        if(branch) begin
            in_branch <= 1'b1;
            has_added <= 1'b0;
            ef_start <= ;
            a_end <= ;
            s_head <= ;
            s_queue <= ;
            s_tail <= ;
            has_suppressed <= 1'b0;
            has_one_suppressed <= 1'b0;
        end
        else if(close_invalid)
            in_branch <= 1'b0;
        else if(close_valid)
            in_branch <= !branch_list_empty;
        if(in_branch) begin
            if(push) 
        end
   end
    
    
    
endmodule
/* verilator lint_on UNUSEDSIGNAL */

