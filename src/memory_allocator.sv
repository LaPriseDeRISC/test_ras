`timescale 1ns / 1ps

/* verilator lint_off UNUSEDSIGNAL */
// allocations and de-allocations are performed in order and
// in a circular manner (oldest allocations are last proposed)
module memory_allocator (clk, 
    alloc, de_alloc, reset, de_alloc_vector,
    last_alloc_addr, reset_addr, alloc_addr,
    vector_size_is_one, vector_size_is_two,
    vector_previous, vector_start, vector_snd, vector_end, vector_next);
    parameter ADDR = 4;
    parameter DEPTH = 16;
    parameter DIRECTION = 1;
    
    input logic clk, alloc, de_alloc, reset, de_alloc_vector, vector_size_is_one, vector_size_is_two;
    input logic [ADDR-1:0] last_alloc_addr, reset_addr;
    input logic [ADDR-1:0] vector_previous, vector_start, vector_snd, vector_end, vector_next;
    output logic [ADDR-1:0] alloc_addr;
   
    logic [ADDR-1:0] next_alloc_addr, next_alloc_addr_ff;
    logic [ADDR-1:0] /*alloc_addr, */ alloc_addr_ff;
    logic read_next_alloc_addr;
    
    logic [ADDR-1:0] free_vector_port_a, free_vector_port_b;
    struct {
        logic read, write;
        logic [ADDR-1:0] output, input, addr;
     } port_a, port_b;
    
    bram #(.DEPTH(DEPTH), .WIDTH(ADDR), .ADDR(ADDR), .OFS(DIRECTION), .BLANK(0))
    free_data(.clk(clk),
          .doa(port_a.output), .ena(port_a.read || port_a.write),
          .dia(port_a.input), .addra(port_a.addr),
          .wea(port_a.write),
          .dob(port_b.output), .enb(port_b.read || port_b.write),
          .dib(port_b.input), .addrb(port_b.addr),
          .web(port_b.write)
          );
    
    assign alloc_addr = de_alloc_vector ? vector_start : alloc_addr_ff;

    assign next_alloc_addr = read_next_alloc_addr ? port_a.output : // read from port_a
                             next_alloc_addr_ff;                    // default from the ff

/** logic of the BRAM control
    always_comb begin
        if(de_alloc_vector) begin
            port_a.addr = vector_previous;
            port_a.input = vector_next;
            port_a.write = 1'b1;
            port_b.addr = last_alloc_addr;
            port_b.input = vector_start;
            port_b.write = 1'b1;
        end else if(de_alloc_vector_end) begin
            port_b.addr = link_next_addr;
            port_b.input = link_next_data;
            port_b.write = 1'b1;
            if(reset) begin
                port_a.addr = reset_addr;
                port_a.read = 1'b1;
            end else if(alloc) begin
                port_a.addr = next_alloc_addr;
                port_a.read = 1'b1;
            end
        end
    end
    */

    assign port_a.addr  = reset ? reset_addr : vector_previous;
    assign port_a.input = vector_next;
    assign port_a.read  = (reset  || (alloc && !de_alloc_vector));
    assign port_a.write = de_alloc_vector;

    assign port_b.addr  = de_alloc_vector_end ? link_next_addr : last_alloc_addr;
    assign port_b.input = de_alloc_vector_end ? link_next_data : vector_start;
    assign port_b.read  = 1'b0;
    assign port_b.write = de_alloc_vector_end || de_alloc_vector;
       
    always_ff @(posedge clk) begin
        if(de_alloc_vector) begin
            //link_prev_addr <= last_alloc_addr;
            //link_next_data <= vector_start;
            link_next_addr <= vector_end;
            link_next_data <= alloc_addr_ff;
            if(alloc)
                alloc_addr_ff <= vector_size_is_one ? alloc_addr_ff : vector_snd; //vector_start is consumed
            else
                alloc_addr_ff <= vector_start; //
        end else if(reset)
            alloc_addr_ff <= reset_addr; //reset to given addr
        else begin
            if(alloc) alloc_addr_ff <= next_alloc_addr;
            if(de_alloc) alloc_addr_ff <= last_alloc_addr; //easy enough
        end
        de_alloc_vector_end <= de_alloc_vector;
    end
    
    always_ff @(posedge clk) begin
        if(de_alloc_vector) begin
            if(alloc)
                next_alloc_addr_ff <= vector_size_is_one ? next_alloc_addr :
                                      (vector_size_is_two ? alloc_addr_ff : vector_thd); //vector_start and snd are consumed
            else
                next_alloc_addr_ff <= vector_size_is_one ? alloc_addr_ff : vector_snd; //
        end else if(de_alloc) next_alloc_addr_ff <= alloc_addr_ff; //easy enough
        else if(read_next_alloc_addr) next_alloc_addr_ff <= port_a.output;

        read_next_alloc_addr <= (reset  || (alloc && !de_alloc_vector));
    end

endmodule