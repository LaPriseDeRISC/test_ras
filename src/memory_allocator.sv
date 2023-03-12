`timescale 1ns / 1ps

/* verilator lint_off UNUSEDSIGNAL */
//allocations and de-allocations are performed in order :
//eg. alloc()->1, alloc()->2, alloc()->3, free(3), free(2), alloc()->2, free(2), free(1)
module memory_allocator (clk, 
    alloc, de_alloc, reset, de_alloc_vector,
    last_alloc_addr, reset_addr, alloc_addr,
    vector_size_is_one, vector_size_is_two,
    vector_previous, vector_start, vector_snd, vector_end, vector_next);
    parameter ADDR = 4;
    parameter DEPTH = 16;
    parameter INITIAL_FETCH = 0;
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
          
    initial begin
         alloc_addr_ff = ADDR'(INITIAL_FETCH);
         read_next_alloc_addr = 1'b1;
    end
          
//    always_ff @(posedge clk) begin
//         if(reset)
//             alloc_addr_ff <= reset_addr;
//         else if(de_alloc)
//             alloc_addr_ff <= free_addr;
//         else if(alloc && de_alloc_vector)
//             alloc_addr_ff <= vector_start;
//         else if(read_alloc_addr)
//             alloc_addr_ff <= free_vector_port_a;
//         read_alloc_addr <= !free_vector && alloc;
//    end
    
//    always_ff @(posedge clk) begin
//         if(de_alloc)
//             next_alloc_addr_ff <= alloc_addr;
//         else if(alloc && de_alloc_vector && !vector_size_is_one)
//             next_alloc_addr_ff <= vector_snd;
//         else if(de_alloc_vector)
//             next_alloc_addr_ff <= vector_start;
//         else if(read_next_alloc_addr)
//             next_alloc_addr_ff <= free_vector_port_b;
//         read_next_alloc_addr <= (!free_vector && alloc) || fetch;
//    end
    
    assign alloc_addr = de_alloc_vector ? vector_start : alloc_addr_ff;

    assign next_alloc_addr = (read_next_alloc_addr ? port_a.output : // read from port_a
                             next_alloc_addr_ff);                    // default from the ff
/** logic of the BRAM control
    always_comb begin
        if(de_alloc_vector) begin
            port_a_addr = vector_previous;
            port_a_data = vector_next;
            port_a_write = 1'b1;
            port_b_addr = last_alloc_addr;
            port_b_data = vector_start;
            port_b_write = 1'b1;
        end else if(de_alloc_vector_end) begin
            port_b_addr = link_next_addr;
            port_b_data = link_next_data;
            port_b_write = 1'b1;
            if(reset) begin
                port_a_addr = reset_addr;
                port_a_read = 1'b1;
            end else if(alloc) begin
                port_a_addr = next_alloc_addr;
                port_a_read = 1'b1;
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
                alloc_addr_ff <= (vector_size_is_one ? alloc_addr_ff : vector_snd); //vector_start is consumed
            else
                alloc_addr_ff <= vector_start; //
        end else if(reset)
            alloc_addr_ff <= reset_addr; //reset to given addr
        else begin
            if(alloc) <= next_alloc_addr;
            if(de_alloc) <= last_alloc_addr; //easy enough
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
        end else if(de_alloc) next_alloc_addr_ff <= alloc_addr; //easy enough
        else if(read_next_alloc_addr) next_alloc_addr_ff <= port_a.output;

        read_next_alloc_addr <= (reset  || (alloc && !de_alloc_vector));
    end

endmodule