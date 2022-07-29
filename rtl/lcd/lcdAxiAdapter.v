`timescale 1ns/1ps

module lcdAxiAdapter (
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

    // ---------------------------------
    // interface to lcd controller 
    output cs, 
    output rs, 
    output wr, 
    output rd, 
    output rst, 
    output [15:0] dout
);
    parameter BaseAddr = 32'h41c0_0000; 
    parameter ReadAddr = 32'h41c0_0004; 

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

    reg cs;
    reg rs; 
    reg wr; 
    reg rd; 
    reg rdflag; 
    reg rst; 
    reg [15:0] dout;
    always @(posedge aclk or negedge aresetn) begin 
        if(~aresetn) begin 
            cs <= 1'b1; 
            rs <= 1'b1; 
            wr <= 1'b1; 
            rd <= 1'b1; 
            rst <= 1'b1;
            dout <= 16'h0; 
        end else begin 
            if(saxi_WVALID & saxi_wready) begin 
                case(saxi_awaddr)
                    BaseAddr: begin 
                        dout <= saxi_WDATA[15:0]; 
                        cs <= saxi_WDATA[28]; 
                        rs <= saxi_WDATA[24]; 
                        wr <= saxi_WDATA[20]; 
                        rst <= saxi_WDATA[16]; 
                    end 

                    default: begin end// do nothing 
                endcase
            end
        end 
    end 

    // read regs 
    always @(*) begin 
        case(saxi_araddr_buffer)
            ReadAddr: begin 
                axi_data_to_read = {16'h0, dout};
            end 
            default: begin end // do nothing  
        endcase 
    end 

endmodule
