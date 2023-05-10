

module ras_links (
    clk, reset,
    incr, decr,
    gen_addr,
    set_addr,
    addr_in,
    addr_out,
    valid,
    full);

    parameter DEPTH = 1024;
    parameter SCRATCHPAD_DEPTH = 16;
    localparam ADDR = $clog2(DEPTH);
    localparam SCRATCHPAD_ADDR = $clog2(SCRATCHPAD_DEPTH);
    localparam BLOCK_ADDR = ADDR-SCRATCHPAD_ADDR;
    localparam BLOCK_DEPTH = DEPTH / SCRATCHPAD_DEPTH;

    input logic clk, reset, incr, decr, gen_addr, set_addr;
    output logic valid, full;
    output logic [ADDR-1:0] addr_out;
    input  logic [ADDR-1:0] addr_in;


    logic [ADDR-1:0] curr_addr_n, curr_addr;
    always @(posedge clk) curr_addr <= curr_addr_n;

    // Lower part of the address
    // this is always linear at the scratchpad scope, so we do +/- 1
    // end / start of blocks are detected here
    wire end_of_block, start_of_block;
    logic [ADDR-1:0] next_addr, prev_addr;
    assign {end_of_block,  next_addr[SCRATCHPAD_ADDR-1:0]} = (SCRATCHPAD_ADDR+1)'(curr_addr[SCRATCHPAD_ADDR-1:0] + 1);
    assign {start_of_block, prev_addr[SCRATCHPAD_ADDR-1:0]}  = (SCRATCHPAD_ADDR+1)'(curr_addr[SCRATCHPAD_ADDR-1:0] - 1);


    logic prev_block_available;
    initial prev_block_available = 1'b0;
    always @(posedge clk) prev_block_available <= !(gen_addr || reset);

    wire alloc_block = incr && end_of_block;
    wire free_block  = decr && start_of_block;

    wire [BLOCK_ADDR-1:0] empty_block, prev_block, next_block;

    wire [BLOCK_ADDR-1:0] curr_block = curr_addr[ADDR-1:SCRATCHPAD_ADDR];
    wire [BLOCK_ADDR-1:0] curr_block_n = curr_addr_n[ADDR-1:SCRATCHPAD_ADDR];
    wire [BLOCK_ADDR-1:0] next_block_n = gen_addr ? empty_block : next_block;

    logic empty_block_valid;
    logic [BLOCK_ADDR-1:0] last_empty_block;
    wire alm_empty = (last_empty_block == empty_block);
    initial last_empty_block = (BLOCK_ADDR)'(-1);
    initial empty_block_valid = 1'b1;
    always @(posedge clk) begin
        if (alloc_block) empty_block_valid <= !alm_empty;
        else if(free_block && !empty_block_valid) begin
            empty_block_valid <=  1'b1;
            last_empty_block <= curr_block;
        end
    end


// maxi système reactif
    ras_bram #(.DEPTH(BLOCK_DEPTH), .WIDTH(BLOCK_ADDR), .OFS(1), .INCR(1), .READ_FIRST(1))
        next_links(.clk(clk), /*.reset(reset),*/
            .doa( empty_block ),    .wia( next_block_n ),
            .raddra( ),             .waddra( curr_block_n ),
            .rea( 1'b0 ),           .wea( alloc_block || free_block || gen_addr ),
                                      // link (new) current_block to (new) next

            .dob( next_block ),     .wib( empty_block ),
            .raddrb( addr_in ),     .waddrb( curr_block ),
            .reb( set_addr ),       .web( alloc_block || free_block ));
                                      // link (old) current_block to (old) empty_block
                                      // when alloc / free:  output = next block
                                      // when setting addr:  output = next_block


    ras_bram #(.DEPTH(BLOCK_DEPTH), .WIDTH(BLOCK_ADDR), .OFS(-1), .INCR(1))
        prev_links(.clk(clk),
            .doa( prev_block ),         .wia( curr_block ),
            .raddra( curr_block_n ),    .waddra( empty_block ),
            .rea( 1'b1 ),               .wea( alloc_block ),
                                      // when alloc: link (new) curr_block to (old) curr_block
                                      // else:       just read (new) curr_block

            .dob( ),  .wib( ),
            .raddrb( ),   .waddrb( ),
            .reb( ),            .web( ));

    always_comb begin
        next_addr[ADDR-1:SCRATCHPAD_ADDR] = curr_block;
        if(end_of_block) begin
            if(empty_block_valid) next_addr[ADDR-1:SCRATCHPAD_ADDR] = empty_block;
            else                  next_addr[ADDR-1:SCRATCHPAD_ADDR] = next_block;
        end
    end

    always_comb begin
        prev_addr[ADDR-1:SCRATCHPAD_ADDR] = curr_block;
        if(start_of_block)  prev_addr[ADDR-1:SCRATCHPAD_ADDR] = prev_block;
    end

    // curr_addr_n calculation here
    always_comb begin
        curr_addr_n = curr_addr;
        if(incr) curr_addr_n = next_addr;
        if(decr) curr_addr_n = prev_addr;
        if(gen_addr) curr_addr_n = {empty_block, SCRATCHPAD_ADDR'(0)};
        if(set_addr) curr_addr_n = addr_in;
    end

    assign addr_out = curr_addr_n;

endmodule : ras_links