
module tb_encdec();

    reg resetn; 
    initial begin
        resetn = 1'b0; 
        #1000 resetn = 1'b1; 
    end 

    reg clk1; 
    initial begin
        clk1 = 1'b1; 
        forever begin
            #10 clk1 = ~clk1; 
        end
    end

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

        #1020;
        encode = 1'b1; 

        #100
        encode = 1'b0; 
    end 

    fbsbencoder uutEncode (
        .pclk(clk1), 
        .resetn(resetn), 
        .encode(encode), 
        .encoding(encoding), 
        .data_in(data), 
        .encoderReady(ready), 
        .tx(tx)
    );

    assign rx = tx; 
    wire [7:0] data_o; 
    wire dataValid; 
    fbsbdecoder uutDecode (
        .pclk(clk1),
        .resetn(resetn), 
        .rx(rx), 
        .data_o(data_o), 
        .dataValid(dataValid)
    );

endmodule
