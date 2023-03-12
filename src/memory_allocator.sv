`timescale 1ns / 1ps
/* verilator lint_off UNUSEDSIGNAL */
//allocations and de-allocations are performed in order :
//eg. alloc()->1, alloc()->2, alloc()->3, free(3), free(2), alloc()->2, free(2), free(1)
module memory_allocator (clk, 
    alloc, free, reset, move_vector, 
    reset_addr, free_addr, alloc_addr, 
    vector_size_is_one, vector_previous, vector_start, vector_snd, vector_end, vector_next);
    parameter ADDR = 4;
    parameter DEPTH = 16;
    parameter INITIAL_FETCH = 0;
    parameter DIRECTION = 1;
    
    input logic clk, free, reset, alloc, move_vector, vector_size_is_one;
    input logic [ADDR-1:0] free_addr, reset_addr;
    input logic [ADDR-1:0] vector_previous, vector_start, vector_snd, vector_end, vector_next;
    output logic [ADDR-1:0] alloc_addr;
   
    logic [ADDR-1:0] next_alloc_addr, next_alloc_addr_ff;
    logic [ADDR-1:0] alloc_addr_ff;
    logic read_alloc_addr, read_next_alloc_addr;
    
    logic [ADDR-1:0] free_vector_port_a, free_vector_port_b;
    
    bram #(.DEPTH(DEPTH), .WIDTH(ADDR), .ADDR(ADDR), .OFS(DIRECTION), .BLANK(0))
    free_data(.clk(clk),
          .doa(free_vector_port_a), .ena(free_vector || alloc),
          .dia(vector_start), .addra(alloc_addr), 
          .wea(free_vector),
          .dob(free_vector_port_b), .enb(free_vector || alloc || fetch),
          .dib(next_alloc_addr), .addrb(free_vector ? vector_end : (fetch ? fetch_addr : next_alloc_addr )), 
          .web(free_vector)
          );   
          
    initial begin
         alloc_addr_ff = ADDR'(INITIAL_FETCH); 
         next_alloc_addr_ff = ADDR'(INITIAL_FETCH + DIRECTION);  
         read_alloc_addr = 1'b0;
         read_next_alloc_addr = 1'b0;
    end
          
//    always_ff @(posedge clk) begin
//        if(free || fetch)
//            addr_out <= addr_in;
//        else if(alloc)
//            if(free_vector) addr_out <= vector_start;
//            else  addr_out <= free_vector_port_a; // read(addr_out)
//    end
    
//    always_ff @(posedge clk) begin
//        if(free)
//            next_addr_out <= addr_out;
//        else if(fetch)
//            next_addr_out <= free_vector_port_b; // read(addr_in)
//        else if(alloc && free_vector && !vector_size_is_one) addr_out <= vector_snd;
//        else if(alloc && !free_vector) addr_out <= free_vector_port_b; // read(next_addr_out)
//        else if(free_vector)
//            addr_out <= vector_start;
//    end
    
    assign alloc_addr = read_alloc_addr ? free_vector_port_a : alloc_addr_ff;
    assign next_alloc_addr = read_next_alloc_addr ? free_vector_port_b : next_alloc_addr_ff;
       
    always_ff @(posedge clk) begin
        if(fetch)
            alloc_addr_ff <= fetch_addr;
        else if(free)
            alloc_addr_ff <= free_addr;
        else if(alloc && free_vector) 
            alloc_addr_ff <= vector_start;
        else if(read_alloc_addr)
            alloc_addr_ff <= free_vector_port_a;
        read_alloc_addr <= !free_vector && alloc;
    end
    
    always_ff @(posedge clk) begin
        if(free)
            next_alloc_addr_ff <= alloc_addr;
        else if(alloc && free_vector && !vector_size_is_one) 
            next_alloc_addr_ff <= vector_snd;
        else if(free_vector)
            next_alloc_addr_ff <= vector_start;
        else if(read_next_alloc_addr)
            next_alloc_addr_ff <= free_vector_port_b;
        read_next_alloc_addr <= (!free_vector && alloc) || fetch;
    end

endmodule