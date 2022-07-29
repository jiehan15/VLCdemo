`timescale 1ns/1ps

module axi_fifo (
    // ------------------------ 
    // AXI interface 
    // global 
    input aclk, 
    input aresetn, 

    // write addr
    input saxi_AWVALID, 
    output saxi_AWREADY, 
    input [31:0] saxi_AWADDR, 
    // input [2:0] saxi_AWPROT, 

    // write data 
    input saxi_WVALID, 
    output saxi_WREADY, 
    input [31:0] saxi_WDATA, 
    // input [3:0] saxi_WSTRB, 

    // write response 
    output saxi_BVALID, 
    input saxi_BREADY, 
    // output [1:0] saxi_BRESP, 

    // read addr
    input saxi_ARVALID, 
    output saxi_ARREADY, 
    input [31:0] saxi_ARADDR, 
    // input [2:0] saxi_ARPORT, 

    // read data
    output saxi_RVALID, 
    input saxi_RREADY, 
    output [31:0] saxi_RDATA, 

    // ----------------------------------
    // interrupt to PS
    output [2:0] irq, 

    // ---------------------------------
    // interface to encoder and decoder 
    input tx_rinc, 
    output [7:0] tx_rdata, 
    output tx_rempty, 

    input rx_winc, 
    input [7:0] rx_wdata, 
    output rx_wfull, 

    // -------------------------------
    // FIFO read control 
    input pclk, 
    input fifo_resetn
);
    parameter BaseAddr = 32'h4000_0000; 
    parameter TxBaseAddr = 32'h4000_0000; 
    parameter RxBaseAddr = 32'h4000_0004; 
    parameter FIFO_PTR = 11; 
    parameter FIFO_WIDTH = 8;   

    parameter FIFO_TIMEOUT = 32; 
    parameter FIFO_OVERRUN = 1024; 

    // write addr; 
    reg saxi_awready; assign saxi_AWREADY = saxi_awready; 
    always @(posedge aclk or negedge aresetn) begin 
        if(~aresetn) begin 
            saxi_awready <= 1'b0; 
        end else begin 
            if(saxi_AWVALID) begin 
                saxi_awready <= 1'b1;
            end else begin 
                saxi_awready <= 1'b0;
            end 
        end 
    end 

    reg [31:0] saxi_awaddr_buffer; 
    always @(posedge aclk or negedge aresetn) begin 
        if(~aresetn) begin 
            saxi_awaddr_buffer <= 32'h0; 
        end else begin 
            // handshake success 
            if(saxi_AWVALID & saxi_awready) begin 
                saxi_awaddr_buffer <= saxi_AWADDR; 
            end
        end 
    end 

    // write data 
    reg saxi_wready; assign saxi_WREADY = saxi_wready; 
    always @(posedge aclk or negedge aresetn) begin 
        if(~aresetn) begin 
            saxi_wready <= 1'b0; 
        end else begin 
            if(saxi_WVALID) begin 
                saxi_wready <= 1'b1;
            end else begin 
                saxi_wready <= 1'b0;
            end 
        end 
    end 

    // write response request 
    reg saxi_need_resp; 
    always @(posedge aclk or negedge aresetn) begin 
        if(~aresetn) begin 
            saxi_need_resp <= 1'b0; 
        end else begin 
            // handshake success 
            if(saxi_WVALID & saxi_wready) begin 
                saxi_need_resp <= 1'b1; 
            end else begin 
                saxi_need_resp <= 1'b0; 
            end 
        end 
    end 

    // address selection 
    // when the data and address come at the same time, 
    // the write addr will not be in the write addr buffer 
    reg [31:0] saxi_awaddr; // real address 
    always @(*) begin 
        // write addr and write data handshake at the same time 
        // the real addr is at the bus; 
        // otherwise the data is at the buffer 
        if((saxi_AWVALID & saxi_awready) & (saxi_WVALID & saxi_wready)) begin 
            saxi_awaddr = saxi_AWADDR; 
        end else begin 
            saxi_awaddr = saxi_awaddr_buffer; 
        end 
    end 

    // AXI write response 
    reg saxi_bvalid; assign saxi_BVALID = saxi_bvalid; 
    always @(posedge aclk or negedge aresetn) begin 
        if(~aresetn) begin 
            saxi_bvalid <= 1'b0; 
        end else begin 
            if(saxi_need_resp) begin 
                saxi_bvalid <= 1'b1; 
            end 

            // handshake success 
            if(saxi_bvalid & saxi_BREADY) begin 
                saxi_bvalid <= 1'b0; 
            end 
        end 
    end 

    // read addr 
    reg saxi_arready; assign saxi_ARREADY = saxi_arready; 
    always @(posedge aclk or negedge aresetn) begin 
        if(~aresetn) begin 
            saxi_arready <= 1'b0; 
        end else begin 
            if(saxi_ARVALID) begin 
                saxi_arready <= 1'b1;
            end else begin 
                saxi_arready <= 1'b0;
            end 
        end 
    end 

    reg [31:0] saxi_araddr_buffer; 
    reg axi_need_read; // read operation request 
    always @(posedge aclk or negedge aresetn) begin 
        if(~aresetn) begin 
            saxi_araddr_buffer <= 32'h0; 
            axi_need_read <= 1'b0; 
        end else begin 
            // handshake success 
            if(saxi_ARVALID & saxi_arready) begin 
                saxi_araddr_buffer <= saxi_ARADDR; 
                axi_need_read <= 1'b1; 
            end else begin 
                axi_need_read <= 1'b0; 
            end 
        end 
    end 

    // read data 
    reg saxi_rvalid; assign saxi_RVALID = saxi_rvalid; 
    reg [31:0] saxi_rdata; assign saxi_RDATA = saxi_rdata; 

    reg axi_wait_for_read; 
    reg [31:0] axi_data_to_read; 
    always @(posedge aclk or negedge aresetn) begin 
        if(~aresetn) begin 
            saxi_rvalid <= 1'b0; 
            saxi_rdata <= 32'h0; 
            axi_wait_for_read <= 1'b0; 
        end else begin 
            if(axi_wait_for_read) begin 
                if(saxi_RREADY) begin 
                    saxi_rdata <= axi_data_to_read; 
                    saxi_rvalid <= 1'b1;

                    // exit wait 
                    axi_wait_for_read <= 1'b0; 
                end 
            end else begin 
                if(axi_need_read & saxi_RREADY) begin 
                    saxi_rdata <= axi_data_to_read; 
                    saxi_rvalid <= 1'b1; 
                end else if(axi_need_read) begin 
                    // wait for rready signal 
                    axi_wait_for_read <= 1'b1; // enter wait 
                    saxi_rvalid <= 1'b0; 
                end else begin 
                    saxi_rvalid <= 1'b0; 
                    saxi_rdata <= 32'h0; 
                end 
            end 
        end 
    end 

    // ----------------------------------------------------------
    // data flow 
    // tx fifo 
    reg tx_winc; 
    reg [7:0] tx_wdata; 
    wire tx_wfull;

    wire tx_overrun; 
    wire tx_tout; 

    async_fifo_core #(
        .FIFO_PTR(FIFO_PTR), 
        .FIFO_WIDTH(FIFO_WIDTH), 
        .FIFO_TIMEOUT(FIFO_TIMEOUT), 
        .FIFO_OVERRUN(FIFO_OVERRUN)
    ) fifo_tx(
        .resetn(fifo_resetn), 

        .wclk(aclk), 
        .winc(tx_winc), 
        .wdata(tx_wdata), 
        .wfull(tx_wfull), 

        .rclk(pclk), 
        .rinc(tx_rinc), 
        .rdata(tx_rdata),
        .rempty(tx_rempty),

        .overrun(tx_overrun), 
        .tout(tx_tout)
    ); 

    // rx fifo 
    reg rx_rinc; 
    wire [7:0] rx_rdata; 
    wire rx_rempty;

    wire rx_overrun; 
    wire rx_tout; 

    async_fifo_core #(
        .FIFO_PTR(FIFO_PTR), 
        .FIFO_WIDTH(FIFO_WIDTH), 
        .FIFO_TIMEOUT(FIFO_TIMEOUT), 
        .FIFO_OVERRUN(FIFO_OVERRUN)
    ) fifo_rx(
        .resetn(fifo_resetn), 

        .wclk(pclk), 
        .winc(rx_winc), 
        .wdata(rx_wdata), 
        .wfull(rx_wfull), 

        .rclk(aclk), 
        .rinc(rx_rinc), 
        .rdata(rx_rdata),
        .rempty(rx_rempty),

        .overrun(rx_overrun), 
        .tout(rx_tout)
    ); 

    // interrupt for PS 
    assign irq[0] = rx_rempty; 
    assign irq[1] = rx_overrun; 
    assign irq[2] = rx_tout; 

    always @(posedge aclk or negedge aresetn) begin 
        if(!aresetn) begin 
            tx_wdata <= 32'h0; 
            tx_winc <= 1'b0; 
        end else begin 
            if(saxi_WVALID & saxi_wready) begin 
                case(saxi_awaddr)
                    TxBaseAddr: begin 
                        tx_wdata <= saxi_WDATA; 
                        tx_winc <= 1'b1; 
                    end 

                    default: begin end// do nothing 
                endcase
            end else begin 
                // automatically reset after write 
                tx_wdata <= 32'h0; 
                tx_winc <= 1'b0; 
            end 
        end 
    end 

    // rx fifo read enable 
    reg rx_read; 
    always @(posedge aclk or negedge aresetn) begin 
        if(~aresetn) begin 
            rx_rinc <= 1'h0; 
            rx_read <= 1'b0; 
        end else begin  
            if(saxi_ARVALID) begin 
                if(saxi_ARADDR == RxBaseAddr) begin 
                    if(~rx_read) begin 
                        rx_rinc <= 1'b1; 
                        rx_read <= 1'b1; 
                    end else begin 
                        rx_rinc <= 1'b0; 
                    end 
                end else begin 
                    rx_rinc <= 1'h0; 
                    rx_read <= 1'b0; 
                end 
            end else begin 
                rx_rinc <= 1'h0; 
                rx_read <= 1'b0; 
            end 
        end 
    end 

    // read regs 
    always @(*) begin 
        case(saxi_araddr_buffer)
            RxBaseAddr: begin 
                axi_data_to_read = rx_rdata; 
            end 
            32'h4000_0008: begin 
                axi_data_to_read = {32{rx_rempty}};
            end 
            default: begin end // do nothing  
        endcase 
    end 

endmodule
