
module serialWrapper(
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

    // to ADAU1761
    input mclk, 
    output lrclk,
    output bclk, 
    output dout
);
    parameter BaseAddr = 32'h41a0_0000; 
    wire rinc; 
    wire [15:0] rdata; 
    wire rempty; 

    serialDataAxi #(
        .BaseAddr(BaseAddr), 
    ) sdataAXI(
        .aclk(aclk), 
        .aresetn(aresetn), 
        .saxi_AWVALID(saxi_AWVALID), 
        .saxi_AWREADY(saxi_AWREADY), 
        .saxi_AWADDR(saxi_AWADDR), 
        .saxi_WVALID(saxi_WVALID), 
        .saxi_WREADY(saxi_WREADY), 
        .saxi_WDATA(saxi_WDATA), 
        .saxi_BVALID(saxi_BVALID), 
        .saxi_BREADY(saxi_BREADY), 
        .saxi_ARVALID(saxi_ARVALID), 
        .saxi_ARREADY(saxi_ARREADY), 
        .saxi_ARADDR(saxi_ARADDR), 
        .saxi_RVALID(saxi_RVALID), 
        .saxi_RREADY(saxi_RREADY), 
        .saxi_RDATA(saxi_RDATA), 
        .tx_rinc(rinc), 
        .tx_rdata(rdata), 
        .tx_rempty(rempty), 
        .mclk(mclk)
    );

    serialDataSimple sdatasimple(
        .mclk(mclk), 
        .resetn(aresetn), 
        .lrclk(lrclk), 
        .bclk(bclk), 
        .dout(dout), 
        .rinc(rinc), 
        .rdata(rdata), 
        .rempty(rempty)
    );

endmodule
