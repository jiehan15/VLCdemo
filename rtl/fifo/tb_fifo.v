`timescale 1ns/1ps

module tb_fifo();

    reg resetn; 
    initial begin
        resetn = 1'b0; 
        #100 resetn = 1'b1; 
    end

    reg wclk; // 100MHZ
    initial begin 
        wclk = 1'b0; 
        forever begin
            #5 wclk = ~wclk; 
        end
    end 

    reg rclk; // 11.1111MHz
    initial begin 
        rclk = 1'b0; 
        forever begin
            #45 rclk = ~rclk; 
        end
    end 

    reg winc; 
    reg rinc; 
    reg [7:0] wdata; 

    wire wfull; 
    wire [7:0] rdata; 
    wire rempty; 
    wire overrun; 
    wire tout; 

    async_fifo_core #(
        .FIFO_PTR(3), 
        .FIFO_OVERRUN(4)
    ) uut (
        .resetn(resetn), 
        .wclk(wclk), 
        .winc(winc), 
        .wdata(wdata), 
        .wfull(wfull), 
        .rclk(rclk), 
        .rinc(rinc), 
        .rdata(rdata), 
        .rempty(rempty), 
        .overrun(overrun), 
        .tout(tout)
    );

    // -------------------------------------------------
    reg [3:0] counter; 
    reg [31:0] testdata; 

    reg writeFinished; 
    always @(posedge wclk or negedge resetn) begin 
        if(~resetn) begin 
            counter <= 4'h0; 
            testdata <= 32'h76b2de5;

            winc <= 1'b0; 
            wdata <= 8'h0; 
            writeFinished <= wfull; 
        end else if(~writeFinished) begin 
            if(counter == 4'hf) begin 
                winc <= 1'b1; 
                counter <= 4'h0; 
                wdata <= testdata[7:0];
                testdata <= {testdata[4:0], testdata[31:5]}; 
            end else begin 
                winc <= 1'b0; 
                counter <= counter + 1'b1; 
            end 
        end 

        if(wfull) begin 
            writeFinished <= 1'b1; 
        end else if(writeFinished & rempty) begin 
            writeFinished <= 1'b0; 
        end 
    end 

    always @(posedge rclk or negedge resetn) begin 
        if(~resetn) begin
            rinc <= 1'b0; 
        end else begin
            if(writeFinished) begin 
                rinc <= ~rinc; 
            end 
        end 
    end 

endmodule
