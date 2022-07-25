
/*
    Manchester Encoder 
    As per IEEE 802.3

    0 -> high-to-low transition 
    1 -> low-to-high transition 
*/

/*************************
    
*/

module manchesterEncoder(
    input clk16x, 
    input resetn, 
    input encode, 

    // data input 
    input [7:0] data_in, 

    // indicate the encoder can accept data 
    output ready, 
    output encoding, 

    // serial data output 
    output tx
);

    reg encoderReady; // 1'b1:  encoder Ready; 1'b0: encoder busy 
    reg encoderReadySync; 
    always @(posedge clk16x) begin encoderReadySync <= encoderReady; end 
    assign ready = ~encoderReadySync & encoderReady; 

    ///////////////////////////////////////////////////////
    // state machine 
    parameter IDLE = 4'h0; 
    parameter SYNCLOW = 4'h1; 
    parameter SYNCHIGH = 4'h2; 
    parameter ENCODE = 4'h3; 

    parameter HalfBitLen = 40; // for 200KHZ

    reg [3:0] curState, nxtState; 
    reg [15:0] curHalfBitCounter, nxtHalfBitCounter; 
    reg [2:0] curIndex, nxtIndex; 
    reg [7:0] dataToSend; 
    reg curTx, nxtTx; assign tx = curTx; 

    always @(posedge clk16x or negedge resetn) begin 
        if(~resetn) begin 
            curState <= IDLE; 
            curHalfBitCounter <= 8'h0; 
            curIndex <= 3'h0; 
            curTx <= 1'b0; 
        end else begin 
            curState <= nxtState; 
            curHalfBitCounter <= nxtHalfBitCounter; 
            curIndex <= nxtIndex; 
            curTx <= nxtTx; 
        end 
    end 

    // state transition logic 
    always @(*) begin 
        nxtState = curState; 
        nxtHalfBitCounter = curHalfBitCounter; 
        nxtIndex = curIndex; 

        case(curState)
            IDLE: begin 
                // if encode begin 
                if(encode) begin 
                    nxtState = SYNCLOW; 
                    nxtHalfBitCounter = 8'h0; 
                end 
            end 

            SYNCLOW: begin 
                if(curHalfBitCounter == (3*HalfBitLen-1)) begin 
                    nxtState = SYNCHIGH; 
                    nxtHalfBitCounter = 8'h0; 
                end else begin 
                    nxtHalfBitCounter = curHalfBitCounter + 1'b1; 
                end 
            end 

            SYNCHIGH: begin 
                if(curHalfBitCounter == (3*HalfBitLen-1)) begin 
                    nxtState = ENCODE; 
                    nxtHalfBitCounter = 8'h0; 
                    nxtIndex = 3'h0; 
                    dataToSend = data_in; 
                end else begin 
                    nxtHalfBitCounter = curHalfBitCounter + 1'b1; 
                end 
            end 

            ENCODE: begin 
                // at the final half bit of a full Byte 
                if((curHalfBitCounter == (2*HalfBitLen-1)) && (curIndex==3'h7)) begin 
                    if(~encode) begin 
                        nxtState = IDLE; 
                    end
                    nxtHalfBitCounter = 8'h0; 
                    nxtIndex = 3'h0; 
                    dataToSend = data_in; 
                end else if(curHalfBitCounter == (2*HalfBitLen-1))begin 
                    nxtIndex = curIndex + 1'b1; 
                    nxtHalfBitCounter = 8'h0; 
                end else begin 
                    nxtHalfBitCounter = curHalfBitCounter + 1'b1; 
                end 


            end 

            default: begin
                nxtState = IDLE; 
            end 
        endcase 
    end 

    // state dependent output 
    always @(*) begin 
        encoderReady = 1'b0;  
        nxtTx = 1'b0; 

        case (curState)
            IDLE: begin 
                nxtTx = 1'b0; 
            end 

            // 3-bit wide sync pulse 
            // 1.5 bit LOW followed by 1.5bit HIGH 
            SYNCLOW: begin 
                encoderReady = 1'b1; 
                nxtTx = 1'b1; 
            end 

            SYNCHIGH: begin 
                nxtTx = 1'b0; 
            end 

            ENCODE: begin 
                if(curHalfBitCounter < HalfBitLen) begin 
                    nxtTx = dataToSend[curIndex] + 1'b1; 
                end else begin 
                    nxtTx = dataToSend[curIndex]; 
                end 

                if(curIndex == 3'h7) begin
                    encoderReady = 1'b1; 
                end
            end 

        endcase
    end 

    reg encoding_reg; 
    assign encoding = encoding_reg; 
    always @(posedge clk16x or negedge resetn) begin 
        if(~resetn) begin 
            encoding_reg <= 1'b0; 
        end else begin 
            if(curState == IDLE) begin 
                encoding_reg <= 1'b0;
            end else begin 
                encoding_reg <= 1'b1; 
            end 
        end 
    end 

endmodule 
