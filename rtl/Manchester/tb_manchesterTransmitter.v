
module tb_manchesterTransmitter();

    // reg resetnDecoder; 
    // initial begin
    //     resetnDecoder = 1'b0; 
    //     #105 resetnDecoder = 1'b1; 
    // end 

    reg resetn; 
    initial begin
        resetn = 1'b0; 
        #100 resetn = 1'b1; 
    end 

    reg clk1; 
    initial begin
        clk1 = 1'b1; 
        forever begin
            #10 clk1 = ~clk1; 
        end
    end

    // reg clk8x; 
    // initial begin
    //     #3; 
    //     clk8x = 1'b1; 
    //     forever begin
    //         #10 clk8x = ~clk8x; 
    //     end
    // end

    wire tx; 
    wire rx; 
    reg [7:0] data; 
    reg write_en; 
    wire ready; 
    reg encode; 
    wire encoding; 

    initial begin 
        encode = 1'b0;
        data = 8'hac; 

        #120;
        encode = 1'b1; 

        #100
        encode = 1'b0; 
    end 

    manchesterEncoder uutEncode (
        .clk16x(clk1), 
        .resetn(resetn), 
        .encode(encode), 
        .encoding(encoding), 
        .data_in(data), 
        .ready(ready), 
        .tx(tx)
    );

    assign rx = tx; 
    wire [7:0] data_o; 
    wire dataValid; 
    wire err; 
    manchesterDecoder uutDecode (
        .rx(rx),
        .clk16x(clk1),
        .resetn(resetn), 
        .data_o(data_o), 
        .dataValid_o(dataValid), 
        .recvErr(err)
    );

    // /////////////////////////////////////////////////
    // // Test logic 
    // // shift register 
    // reg [31:0] testData; 
    // reg [1:0] index;

    // reg ready_delay; 
    // wire ready_raising; 
    // always @(posedge clk1) begin 
    //     if(~resetn) begin 
    //         ready_delay <= 1'b0; 
    //     end else begin 
    //         ready_delay <= ready; 
    //     end 
    // end 

    // assign ready_raising = ~ready_delay & ready; 

    // always @(posedge clk1) begin 
    //     // if(~resetnEncoder) begin 
    //     //     testData <= 32'hed501652;
    //     // end else begin 
    //     //     testData <= {testData[0], testData[31:1]};
    //     // end 
    //     if(~resetn) begin 
    //         testData <= 32'hed501652;
    //         data <= 8'h0;
    //         index <= 2'h0; 
    //     end else begin 
    //         if(ready_raising) begin 
    //             data <= testData[(8*index) +: 8];
    //             write_en <= 1'b1; 
    //             index <= index + 1'b1; 

    //             if(index == 2'h33) begin 
    //                 testData <= {testData[4:0], testData[31:5]};
    //             end 
    //         end else begin 
    //             write_en <= 1'b0; 
    //         end 
    //     end 
    // end 


endmodule 
