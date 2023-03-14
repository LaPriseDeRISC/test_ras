`timescale 1ns / 1ps
/* verilator lint_off UNOPTFLAT */
/* verilator lint_off UNUSEDSIGNAL */
// allocations and de-allocations are performed in order and
// in a circular manner (oldest allocations are last proposed)
module memory_allocator (clk,
    alloc, de_alloc, reset, de_alloc_vector,
    last_alloc_addr, reset_addr, alloc_addr,
    vec_intf);
    parameter ADDR = 4;
    parameter DEPTH = 16;
    parameter DIRECTION = 1;
    parameter INITIAL_ADDR = 0;

    typedef struct packed{
        logic size_is_one, size_is_two;
        logic [ADDR-1:0] previous, head, second, third, tail, next;
    } vector_t;
    
    input logic clk, alloc, de_alloc, reset, de_alloc_vector;
    input logic [ADDR-1:0] last_alloc_addr, reset_addr;
    input vector_t vec_intf;
    output logic [ADDR-1:0] alloc_addr;

    logic [ADDR-1:0] next_alloc_addr, next_alloc_addr_ff;
    logic [ADDR-1:0] /*alloc_addr, */ alloc_addr_ff;
    logic [ADDR-1:0] link_next_addr, link_next_data;
    logic read_next_alloc_addr, de_alloc_vector_end;

    initial begin
        next_alloc_addr_ff = ADDR'(INITIAL_ADDR + DIRECTION);
        alloc_addr_ff = ADDR'(INITIAL_ADDR);
    end

    logic [ADDR-1:0] free_vector_port_a, free_vector_port_b;
    struct {
        logic read, write;
        logic [ADDR-1:0] out, in, addr;
     } port_a, port_b;
    
    bram #(.DEPTH(DEPTH), .WIDTH(ADDR), .ADDR(ADDR), .OFS(DIRECTION), .BLANK(0))
    free_data(.clk(clk),
          .doa(port_a.out), .ena(port_a.read || port_a.write),
          .dia(port_a.in), .addra(port_a.addr),
          .wea(port_a.write),
          .dob(port_b.out), .enb(port_b.read || port_b.write),
          .dib(port_b.in), .addrb(port_b.addr),
          .web(port_b.write)
          );
    
    assign alloc_addr = de_alloc_vector ? vec_intf.head : alloc_addr_ff;

    assign next_alloc_addr = read_next_alloc_addr ? port_a.out : // read from port_a
                             next_alloc_addr_ff;                    // default from the ff

/** logic of the BRAM control
    always_comb begin
        if(de_alloc_vector) begin
            port_a.addr = vec_intf.previous;
            port_a.in    = vec_intf.next;
            port_a.write = 1'b1;
            port_b.addr = last_alloc_addr;
            port_b.in    = vec_intf.head;
            port_b.write = 1'b1;
        end else if(de_alloc_vector_end) begin
            port_b.addr = link_next_addr;
            port_b.in    = link_next_data;
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

    assign port_a.addr  = reset ? reset_addr :
                            de_alloc_vector ? vec_intf.previous : next_alloc_addr;
    assign port_a.in    = vec_intf.next;
    assign port_a.read  = (reset  || (alloc && !de_alloc_vector));
    assign port_a.write = de_alloc_vector;

    assign port_b.addr  = de_alloc_vector_end ? link_next_addr : last_alloc_addr;
    assign port_b.in    = de_alloc_vector_end ? link_next_data : vec_intf.head;
    assign port_b.read  = 1'b0;
    assign port_b.write = de_alloc_vector_end || de_alloc_vector;
       
    always_ff @(posedge clk) begin
        if(de_alloc_vector) begin
            //link_prev_addr <= last_alloc_addr;
            //link_next_data <= vec_intf.head;
            link_next_addr <= vec_intf.tail;
            link_next_data <= alloc_addr_ff;
            if(alloc)
                alloc_addr_ff <= vec_intf.size_is_one ? alloc_addr_ff : vec_intf.second; //head is consumed
            else
                alloc_addr_ff <= de_alloc ? last_alloc_addr : vec_intf.head; //
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
                next_alloc_addr_ff <= vec_intf.size_is_one ? next_alloc_addr :
                                      (vec_intf.size_is_two ? alloc_addr_ff : vec_intf.third); //head and snd are consumed
            else
                next_alloc_addr_ff <= (vec_intf.size_is_one || de_alloc)? alloc_addr_ff : vec_intf.second; //
        end else if(de_alloc) next_alloc_addr_ff <= alloc_addr_ff; //easy enough
        else if(read_next_alloc_addr) next_alloc_addr_ff <= port_a.out;

        read_next_alloc_addr <= (reset  || (alloc && !de_alloc_vector));
    end

endmodule
