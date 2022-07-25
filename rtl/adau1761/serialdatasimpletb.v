module sdatasimple_tb();

    reg aclk; 
    initial begin
        aclk = 1'b1;
        forever begin
            #5 aclk = ~aclk; 
        end
    end

    reg mclk; 
    initial begin
        mclk = 1'b1;
        forever begin
            #20 mclk = ~mclk; 
        end
    end

    reg resetn;
    initial begin
        resetn <= 1'b0;
        # 105 resetn <= 1'b1; 
    end 

    wire lrclk;
    wire bclk; 

    parameter FIFO_PTR = 6; 
    parameter FIFO_WIDTH = 16;   

    parameter FIFO_TIMEOUT = 64; 
    parameter FIFO_OVERRUN = 24; 

    // ----------------------------------------------------------
    // data flow 
    // tx fifo 
    reg tx_winc; 
    reg [15:0] tx_wdata; 
    initial begin
        tx_winc <= 1'b0;
        tx_wdata <= 16'h0;

        #110
        tx_winc <= 1'b1;
        tx_wdata <= 16'h8231;

        #12
        tx_winc <= 1'b0;
        tx_wdata <= 16'h0;

        #18
        tx_winc <= 1'b1;
        tx_wdata <= 16'h4567;
        
        #12
        tx_winc <= 1'b0;
        tx_wdata <= 16'h0;

        #18
        tx_winc <= 1'b1;
        tx_wdata <= 16'h754f;
        
        #12
        tx_winc <= 1'b0;
        tx_wdata <= 16'h0;

        #18
        tx_winc <= 1'b1;
        tx_wdata <= 16'h9ab1;
        
        #12
        tx_winc <= 1'b0;
        tx_wdata <= 16'h0;
    end 

    wire tx_wfull;

    wire tx_rinc; 
    wire [15:0] tx_rdata; 
    wire tx_rempty;

    async_fifo_core #(
        .FIFO_PTR(FIFO_PTR), 
        .FIFO_WIDTH(FIFO_WIDTH), 
        .FIFO_TIMEOUT(FIFO_TIMEOUT), 
        .FIFO_OVERRUN(FIFO_OVERRUN)
    ) fifo_tx(
        .resetn(resetn), 

        .wclk(aclk), 
        .winc(tx_winc), 
        .wdata(tx_wdata), 
        .wfull(tx_wfull), 

        .rclk(mclk), 
        .rinc(tx_rinc), 
        .rdata(tx_rdata),
        .rempty(tx_rempty)
    ); 

    wire dout; 

    serialDataSimple uut(
        .mclk(mclk), 
        .resetn(resetn), 
        .lrclk(lrclk), 
        .bclk(bclk), 
        .dout(dout), 
        .rinc(tx_rinc), 
        .rdata(tx_rdata), 
        .rempty(tx_rempty)
    );

endmodule