`timescale 1ns/1ps

module async_fifo_core#(
    parameter FIFO_PTR = 12, // 4KiB
    parameter FIFO_WIDTH = 8,  

    parameter FIFO_TIMEOUT = 16,  
    parameter FIFO_OVERRUN = 2048  // in bytes 
)
(
    input resetn, 

    input wclk, 
    input winc, // write enable 
    input [FIFO_WIDTH-1 : 0] wdata, 
    output wfull, 

    input rclk, 
    input rinc, // read enable 
    output [FIFO_WIDTH-1 : 0] rdata, 
    output rempty, 

    // interrupt 
    output overrun, 
    output tout
);
    // --------------------------------------------------
    // write opreation 
    wire [FIFO_PTR-1 : 0] waddr; 
    wire waddr_overflow; 

    addrcnt #(
        .width(FIFO_PTR+1)
    ) w_addr_cnt (
        .resetn(resetn), 
        .clk(wclk), 
        .en(winc & ~wfull), // disable write when FIFO is full 
        .count({waddr_overflow, waddr})
    );

    // --------------------------------------------------
    // read opreation 
    wire [FIFO_PTR-1 : 0] raddr; 
    wire raddr_overflow; 

    addrcnt #(
        .width(FIFO_PTR+1)
    ) r_addr_cnt (
        .resetn(resetn), 
        .clk(rclk), 
        .en(rinc & ~rempty), // disable write when FIFO is full 
        .count({raddr_overflow, raddr})
    );

    // --------------------------------------------------
    // grey code conversion: write 
    wire [FIFO_PTR:0] wptr; 
    assign wptr = ({waddr_overflow, waddr} >> 1) ^ ({waddr_overflow, waddr});

    // two taps to prevent unsatble state 
    reg [FIFO_PTR:0] sync_w2r_0; 
    reg [FIFO_PTR:0] sync_w2r_1;

    always @(posedge rclk or negedge resetn) begin 
        if(~resetn) begin 
            sync_w2r_0 <= 32'h0; 
            sync_w2r_1 <= 32'h0; 
        end else begin 
            sync_w2r_0 <= wptr; 
            sync_w2r_1 <= sync_w2r_0; 
        end 
    end  

    // --------------------------------------------------
    // gray code conversion: write 
    wire [FIFO_PTR:0] rptr; 
    assign rptr = ({raddr_overflow, raddr} >> 1) ^ ({raddr_overflow, raddr});

    // two taps to prevent unsatble state 
    reg [FIFO_PTR:0] sync_r2w_0; 
    reg [FIFO_PTR:0] sync_r2w_1;

    always @(posedge rclk or negedge resetn) begin 
        if(~resetn) begin 
            sync_r2w_0 <= 32'h0; 
            sync_r2w_1 <= 32'h0; 
        end else begin 
            sync_r2w_0 <= rptr; 
            sync_r2w_1 <= sync_r2w_0; 
        end 
    end  

    // --------------------------------------------------
    // read address decode 
    reg [FIFO_PTR:0]       wq2_rptr_decode;
    integer i; 
    // grey code decode 
    always @(*) begin 
        wq2_rptr_decode[FIFO_PTR] = sync_r2w_1[FIFO_PTR]; 

        for(i=FIFO_PTR-1; i>=0; i=i-1) begin 
             wq2_rptr_decode[i] = wq2_rptr_decode[i+1] ^ sync_r2w_1[i] ;
        end 
    end 

    // --------------------------------------------------
    // write address decode 
    reg [FIFO_PTR:0]       rq2_wptr_decode;
    integer j; 
    // grey code decode 
    always @(*) begin 
        rq2_wptr_decode[FIFO_PTR] = sync_w2r_1[FIFO_PTR]; 

        for(j=FIFO_PTR-1; j>=0; j=j-1) begin 
             rq2_wptr_decode[j] = rq2_wptr_decode[j+1] ^ sync_w2r_1[j] ;
        end 
    end 

    // --------------------------------------------------
    // empty and full signal (overrun, timeout)
    // empty: read and write address are equal, the overflow is the same 
    assign rempty = ( 
        (raddr_overflow == rq2_wptr_decode[FIFO_PTR]) && 
        (raddr >= rq2_wptr_decode[FIFO_PTR-1 : 0])
        );

    // full: read and write address are equal, the overflow is NOT same 
    assign wfull = ( 
        (waddr_overflow != wq2_rptr_decode[FIFO_PTR]) && 
        (waddr >= wq2_rptr_decode[FIFO_PTR-1 : 0])
        );

    // when the extended bit is the same, the write address is equal or 
    // greater than the read address; 
    // otherwise, the write address is equal or smaller than the read address; 
    assign overrun = 
        (waddr_overflow == raddr_overflow) ? 
        ( (waddr - wq2_rptr_decode[FIFO_PTR-1 : 0]) >= FIFO_OVERRUN-1 ) : 
        ( (waddr + (1<<FIFO_PTR) - wq2_rptr_decode[FIFO_PTR-1 : 0]) >= FIFO_OVERRUN-1);

        // if 16 clock cycle no data feed 
    reg [31:0] wcounter; 
    reg tout_reg; assign tout = tout_reg; 
    always @(posedge wclk or negedge resetn) begin 
        if(~resetn) begin 
            wcounter <= 16'h0; 
        end else begin
            if (winc & ~wfull)begin 
                wcounter <= 16'h0; 
            end else begin 
                wcounter <= wcounter + 1'b1;
            end 
        end 
    end 
    always @(posedge wclk or negedge resetn) begin 
        if(~resetn) begin 
            tout_reg <= 1'b0; 
        end else begin
            if(wcounter > FIFO_TIMEOUT-1) begin 
                tout_reg <= 1'b1; 
            end else begin 
                tout_reg <= 1'b0; 
            end 
        end 
    end 


    // --------------------------------------------------
    // dualport memory 
    dualPortRam #(
        .PTR(FIFO_PTR), 
        .WIDTH(FIFO_WIDTH)
    ) ramdp (
        .resetn(resetn), 
        .wclk(wclk), 
        .wen(winc & ~wfull), 
        .waddr(waddr), 
        .wdata(wdata), 
        .rclk(rclk), 
        .ren(rinc & ~rempty), 
        .raddr(raddr), 
        .rdata(rdata)
    );

endmodule 

module addrcnt #(
    parameter width = 12 
) (
    input resetn, 
    input clk, 
    input en, 
    output [width-1 : 0] count
);

    reg [width-1 : 0] count_reg; assign count = count_reg; 
    always @(posedge clk or negedge resetn) begin
        if(~resetn) begin 
            count_reg <= 32'b0; 
        end else begin 
            if(en) begin 
                count_reg <= count_reg + 1'b1; 
            end else begin 
                count_reg <= count_reg; 
            end 
        end 
    end
    
endmodule

module dualPortRam #(
    parameter PTR = 12, 
    parameter WIDTH = 8
)(
    input resetn, 
    input wclk, 
    input wen, 
    input [PTR-1 : 0] waddr, 
    input [WIDTH-1 : 0] wdata, 

    input rclk, 
    input ren, 
    input [PTR-1 : 0] raddr, 
    output [WIDTH-1 : 0] rdata
);

    // memory 
    reg [WIDTH-1 : 0] mem[(2**PTR - 1) : 0]; 

    reg [WIDTH-1 : 0] rdata_reg; 
    assign rdata = rdata_reg; 

    // write 
    always @(posedge wclk) begin 
        if(wen) begin 
            mem[waddr] <= wdata; 
        end 
    end 

    // read
    always @(posedge rclk) begin 
        if(ren) begin 
            rdata_reg <= mem[raddr]; 
        end 
    end 

endmodule
