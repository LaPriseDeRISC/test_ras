`timescale 1ns / 1ps

module ras (clk, pop, push, branch, close_valid, close_invalid, din, dout);
    //parameter MAXBRANCHES = 1024;
    //parameter BRANCHES_ADDR = 10;
    parameter DEPTH = 1024;
    parameter WIDTH = 32;
    parameter ADDR = 10;;          
    input clk, pop, push, branch, close_valid, close_invalid;
    input logic [WIDTH-1:0] din;
    output logic [WIDTH-1:0] dout;
    logic [WIDTH-1:0] data_writeback;
    logic rewrite_pop_value;
    
    logic update_push_queue, update_pop_queue;
    logic write_push_head_next;
    
    logic [ADDR-1:0] next_push_addr/*verilator public*/, next_pop_addr/*verilator public*/, next_deleted_addr, push_head_next_value, next_preserved_addr;
    logic [ADDR-1:0] push_head, push_queue, pop_head, pop_queue, deleted_head, preserved_head;
        
    //logic has_deleted_values;
    logic has_added_values;
    logic in_branch;
    
    //fifo #(.DEPTH(MAXBRANCHES), .WIDTH(1 + ADDR * 2), .ADDR(BRANCHES_ADDR))
    //branches(.clk(clk),
    //         .din({branch_added, branch_deleted, has_deleted_values}));
             
    bram #(.DEPTH(DEPTH), .WIDTH(32), .ADDR(ADDR))
    data(.clk(clk),
         .doa(dout), .dia(data_writeback), .addra(next_pop_addr), .ena(pop), .wea(rewrite_pop_value),
         .dib(din), .dob(data_writeback), .addrb(next_push_addr), .enb(push), .web(push));
    /* verilator lint_off PINCONNECTEMPTY */
    bram #(.DEPTH(DEPTH), .WIDTH(10), .ADDR(ADDR), .OFS(-1), .BLANK(0))
    prev_links(.clk(clk),
          .doa(push_queue), .ena(update_push_queue),
          .dia('b0), .addra(push_queue), 
          .wea(1'b0),
          .dob(), .enb(1'b0),
          .dib('b0), .addrb('b0), 
          .web(1'b0)
          );
   
   bram #(.DEPTH(DEPTH), .WIDTH(10), .ADDR(ADDR), .OFS(1), .BLANK(0))
    next_links(.clk(clk),
          .doa(pop_queue), .ena(update_pop_queue),
          .dia('b0), .addra(pop_queue), 
          .wea(1'b0),
          .dob(), .enb(write_push_head_next),
          .dib(push_head_next_value), .addrb(push_head), 
          .web(write_push_head_next)
          );
   /* verilator lint_on PINCONNECTEMPTY */
   always_comb begin
        rewrite_pop_value = pop && push && !(in_branch && ! has_added_values);
        write_push_head_next = push && (!rewrite_pop_value);
        update_pop_queue = pop && !push;
        update_push_queue = push;
        push_head_next_value = (pop && push) ? pop_queue : pop_head;
        next_push_addr = push ? (rewrite_pop_value ? push_head : push_queue) :
                         (pop && !(in_branch && ! has_added_values) ? pop_head : push_head) ;
        next_pop_addr = push ? (rewrite_pop_value ? pop_head : push_head) : 
                         (pop ? pop_queue : pop_head); 
        next_deleted_addr = pop && (in_branch && ! has_added_values) ? pop_head : deleted_head;
        next_preserved_addr = pop && (in_branch && ! has_added_values) ? pop_queue : preserved_head;
   end     
    
    always_ff @(posedge clk) begin
    	preserved_head <= next_preserved_addr;
    	in_branch <= (close_valid || close_invalid) ? 1'b0 : (branch ? 1'b1 : in_branch);
        push_head <= next_push_addr;
        pop_head <= next_pop_addr;
        deleted_head <= next_deleted_addr;
        has_added_values <= (next_preserved_addr == next_pop_addr) ? 1'b0 : 1'b1;
    end
    
    
    
endmodule

