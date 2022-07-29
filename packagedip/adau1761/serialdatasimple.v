
module serialDataSimple(
    input mclk, 
    input resetn, 
    
    // to adau1761
    output lrclk, 
    output bclk, 
    output dout, 

    // to txfifo 
    output rinc, 
    input [15:0] rdata, 
    input rempty
);

    // the mclk is 256*fs

    // the lrclk is fs, and the low = left channel 
    // the high = right channel. the transmitted data 
    // is delayed 1 bclk 

    // blck*64 = lrclk 

    reg [7:0] lrclkdiv; 

    always @(posedge mclk or negedge resetn) begin 
        if(~resetn) begin 
            lrclkdiv <= 8'h0; 
        end else begin 
            lrclkdiv <= lrclkdiv + 1'b1; 
        end 
    end 

    assign lrclk = lrclkdiv[7];
    assign bclk = lrclkdiv[1]; 

    // state machine 
    reg [3:0] curState, nxtState; 
    reg curDout, nxtDout; 
    reg [3:0] curIndex, nxtIndex; 
    reg curRinc, nxtRinc; 
    reg [15:0] dataBuffer; 

    assign rinc = curRinc; 
    assign dout = curDout; 

    always @(posedge mclk or negedge resetn) begin 
        if(~resetn) begin 
            curState <= 4'h0; 
            curDout <= 1'b0; 
            curIndex <= 4'hf; 
            curRinc <= 1'b0; 
        end else begin 
            curState <= nxtState; 
            curDout <= nxtDout; 
            curIndex <= nxtIndex; 
            curRinc <= nxtRinc; 
        end 
    end 

    always @(*) begin 
        nxtState = curState; 
        nxtDout = curDout; 
        nxtIndex = curIndex;
        nxtRinc = 1'b0; 

        case(curState)
            // IDLE state 
            // at the beginning of each lrclk, if the tx fifo is not 
            // empty then read the data and 
            4'h0: begin 
                if(lrclkdiv == 8'h00) begin 
                    if(~rempty) begin 
                        nxtState = 4'h1; 
                        nxtRinc = 1'b1; 
                        nxtIndex = 4'hf; 
                    end else begin 
                        dataBuffer = 16'h0; 
                    end 
                end 
            end 

            4'h1: begin 
                // wait for data valid 
                nxtState = 4'h2; 
            end 

            4'h2: begin 
                dataBuffer = rdata; 
                nxtState = 4'h3; 
            end 

            // set data at falling edge 
            4'h3: begin 
                if(lrclkdiv[1:0] == 2'b11) begin 
                    nxtDout = dataBuffer[curIndex]; 
                    nxtIndex = curIndex - 1'b1; 

                    if(curIndex == 4'h0) begin 
                        nxtState = 4'h4; 
                    end 
                end 
            end 

            4'h4: begin 
                if(lrclkdiv == 8'h7f) begin 
                    nxtState = 4'h5;
                    nxtRinc = 1'b1; 
                    nxtIndex = 4'hf; 
                end else if(lrclkdiv[1:0] == 2'b11) begin 
                    nxtDout = 1'b0; 
                end 
            end 

            4'h5: begin 
                nxtState = 4'h6; 
            end 

            4'h6: begin 
                dataBuffer = rdata; 
                nxtState = 4'h7; 
            end 

            // right channel  
            4'h7: begin 
                if(lrclkdiv[1:0] == 2'b11) begin 
                    nxtDout = dataBuffer[curIndex]; 
                    nxtIndex = curIndex - 1'b1; 

                    if(curIndex == 4'h0) begin 
                        nxtState = 4'h8; 
                    end
                end 
            end 

            4'h8: begin 
                if(lrclkdiv == 8'hff) begin 
                    if(rempty) begin 
                        nxtState = 4'h0; 
                    end else begin 
                        nxtState = 4'h1; 
                        nxtRinc = 1'b1; 
                        nxtIndex = 4'hf; 
                    end 
                end else if(lrclkdiv[1:0] == 2'b11) begin 
                    nxtDout = 1'b0; 
                end 
            end 
        endcase 
    end 

endmodule
