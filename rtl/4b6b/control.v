
module control(
    input pclk, 
    input resetn, 

    output tx_rinc, 
    input [7:0] tx_rdata, 
    input tx_rempty,
    output tx, 

    output rx_winc, 
    output [7:0] rx_wdata, 
    input rx_wfull, 
    input rx
);
    parameter pwmen = 1'b1; 

    reg encode; 
    wire encoderready; 
    wire encoding; 
    wire encoderTX; 
    wire break; 

    // manchesterEncoder men(
    //     .clk16x(pclk), 
    //     .resetn(resetn), 
    //     .encode(encode), 
    //     .data_in(tx_rdata), 
    //     .ready(encoderready),
    //     .encoding(encoding), 
    //     .tx(encoderTX) 
    // );
    fbsbencoder uutEncode (
        .pclk(pclk), 
        .resetn(resetn), 
        .encode(encode), 
        .encoding(encoding), 
        .data_in(tx_rdata), 
        .encoderReady(encoderready), 
        .tx(encoderTX), 
        .break(break)
    );

    // always on counter
    reg [15:0] pwmcounter; 
    always @(posedge pclk or negedge resetn) begin 
        if(~resetn) begin 
            pwmcounter <= 16'h0; 
        end else begin 
            if(encoding) begin 
                pwmcounter <= pwmcounter; 
            end else begin 
                pwmcounter <= pwmcounter + 1'b1; 
            end 
        end 
    end 

generate
    if(pwmen) begin : PWM0
        txMuX txmux(
            .pwm(pwmcounter[12]), 
            // .pwm(1'b0), 
            .tx_i(encoderTX), 
            .encoding(encoding), 
            .tx_o(tx)
        );
    end else begin : PWM1
        txMuX txmux(
            .pwm(1'b0), 
            .tx_i(encoderTX), 
            .encoding(encoding), 
            .tx_o(tx)
        );
    end 
endgenerate

    // tx state machine 
    reg [3:0] tx_curState, tx_nxtState; 
    reg tx_rinc_reg; assign tx_rinc = tx_rinc_reg; 
    reg tx_curLow, tx_nxtLow; 
    reg [15:0] tx_curLowCounter, tx_nxtLowCounter; 

    always @(posedge pclk or negedge resetn) begin 
        if(~resetn) begin 
            tx_curState <= 1'b0; 
            tx_curLow <= 1'b0; 
            tx_curLowCounter <= 16'h0; 
        end else begin 
            tx_curState <= tx_nxtState; 
            tx_curLow <= tx_nxtLow;
            tx_curLowCounter <= tx_nxtLowCounter;
        end 
    end 

    always @(*) begin 
        tx_nxtState = tx_curState; 
        tx_rinc_reg = 1'b0; 
        tx_nxtLow = tx_curLow; 
        tx_nxtLowCounter = tx_curLowCounter; 

        case(tx_curState)
            // IDLE 
            4'h0: begin 
                tx_nxtLowCounter = 16'h0; 
                encode = 1'b0; 
                if(~tx_rempty) begin 
                    if(pwmcounter[12]) begin 
                        // tx line is ready 
                        tx_nxtState = 4'h1;
                        encode = 1'b1; 
                    end else begin 
                        tx_nxtState = 4'h3;
                        tx_nxtLow = pwmcounter[12]; 
                    end 
                end 
            end 

            // get the tx line ready for hand shake
            4'h3: begin 
                if(tx_curLowCounter == 16'd849) begin 
                    tx_nxtState = 4'h1; 
                    encode = 1'b1; 
                    tx_nxtLowCounter = 16'h0; 
                end else begin 
                    tx_nxtState = 4'h3; 
                    encode = 1'b0; 
                    tx_nxtLowCounter = tx_curLowCounter + 1'b1; 
                end 
            end 

            // encoder 
            4'h1: begin 
                if(encoderready) begin 
                    tx_rinc_reg = 1'b1; 
                    tx_nxtState = 4'h2; 
                end 
            end 

            4'h2: begin 
                // wait for sending 
                if(break) begin 
                    tx_nxtState = 4'h4; 
                    tx_nxtLowCounter = 16'h0; 
                end else if(encoderready) begin 
                    if(~tx_rempty) begin 
                        encode = 1'b1; 
                        tx_rinc_reg = 1'b1; 
                    end else begin 
                        encode = 1'b0; 
                        tx_nxtState = 4'h0; 
                    end 
                end
            end 

            4'h4: begin 
                // wait for one symbol 
                encode = 1'b0; 
                if(tx_curLowCounter == 16'd599) begin 
                    tx_nxtState = 4'h0; 
                end else begin 
                    tx_nxtLowCounter = tx_curLowCounter + 1'b1; 
                end 
            end 
        endcase 
    end 

    // --------------------------------------------------------
    // decoder 
    wire [7:0] data_o; 
    wire dataValid; 

    fbsbdecoder uutDecode (
        .pclk(pclk),
        .resetn(resetn), 
        .rx(rx), 
        .data_o(data_o), 
        .dataValid(dataValid)
    );

    reg rx_winc_reg; 
    reg [7:0] rx_wdata_reg; 

    assign rx_winc = rx_winc_reg;
    assign rx_wdata = rx_wdata_reg; 

    always @(posedge pclk or negedge resetn) begin 
        if(~resetn) begin 
            rx_winc_reg <= 1'b0; 
            rx_wdata_reg <= 8'h0; 
        end else begin 
            if(~rx_wfull & dataValid) begin 
                rx_wdata_reg <= data_o; 
                rx_winc_reg <= 1'b1; 
            end else begin 
                rx_winc_reg <= 1'b0; 
            end 
        end 
    end
 
endmodule 

module txMuX(
    input pwm, 
    input tx_i, 
    input encoding, 
    output tx_o
);

     assign tx_o = encoding ? tx_i : pwm; 
endmodule 
