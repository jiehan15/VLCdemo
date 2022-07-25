
module fbsbencoder(
    input pclk, 
    input resetn, 

    input encode, 
    input [7:0] data_in, 
    
    output encoderReady, 
    output encoding, 
    output tx, 

    output break 
);

    wire [11:0] data12b_wire; 
    fourBit2SixBit lower(
        .fourbitin(data_in[3:0]), 
        .sixbitout(data12b_wire[5:0])
    );
    fourBit2SixBit higher(
        .fourbitin(data_in[7:4]), 
        .sixbitout(data12b_wire[11:6])
    );

    reg [11:0] data12b; 
    always @(posedge pclk) begin 
        data12b <= data12b_wire; 
    end 

    parameter BitLength = 32'd50; // 320KHz 
    parameter FrameLen = 16'd23; 

    /////////////////////////////////////////
    // state machine 
    parameter IDLE = 4'h0; 
    parameter SYNCHIGH = 4'h1; // five bit high 
    parameter SYNCLOW = 4'h2; // five bit low 

    parameter ENCODE0 = 4'h3;  
    parameter ENCODE1 = 4'h4;  
    parameter ENCODE2 = 4'h5;  
    parameter ENCODE3 = 4'h6;  
    parameter ENCODE4 = 4'h7;  
    parameter ENCODE5 = 4'h8;  
    parameter ENCODE6 = 4'h9;  
    parameter ENCODE7 = 4'ha;  
    parameter ENCODE8 = 4'hb;  
    parameter ENCODE9 = 4'hc;  
    parameter ENCODEa = 4'hd;  
    parameter ENCODEb = 4'he;  

    reg [3:0] curState, nxtState; 
    reg curTx, nxtTx; 
    reg [15:0] curBitCounter, nxtBitCounter; 
    reg curRdy, nxtRdy; 

    reg [7:0] curSymbolCounter, nxtSymbolCounter; 
    reg break; 
    
    reg [11:0] dataBuffer;

    assign tx = curTx; 

    always @(posedge pclk or negedge resetn) begin 
        if(~resetn) begin 
            curState <= IDLE; 
            curTx <= 1'b0; 
            curBitCounter <= 16'h0; 
            curRdy <= 1'b0; 
            curSymbolCounter <= 8'h0; 
        end else begin 
            curState <= nxtState; 
            curTx <= nxtTx; 
            curBitCounter <= nxtBitCounter; 
            curRdy <= nxtRdy; 
            curSymbolCounter <= nxtSymbolCounter; 
        end 
    end 

    always @(*) begin 
        nxtState = curState; 
        nxtBitCounter = curBitCounter; 
        nxtTx = curTx; 
        nxtRdy = curRdy; 
        nxtSymbolCounter = curSymbolCounter; 
        break = 1'b0; 

        case(curState)
            IDLE: begin 
                nxtTx = 1'b0; 
                nxtRdy = 1'b0; 
                if(encode) begin 
                    nxtState = SYNCHIGH; 
                    nxtBitCounter = 16'h0; 
                end
            end 

            SYNCHIGH: begin 
                if(curBitCounter == (5*BitLength-1)) begin 
                    nxtState = SYNCLOW; 
                    nxtBitCounter = 16'h0; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = 1'b1; 
                end 
            end 

            SYNCLOW: begin 
                if(curBitCounter == (5*BitLength-1)) begin 
                    nxtState = ENCODE0; 
                    nxtBitCounter = 16'h0; 
                    dataBuffer = data12b; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = 1'b0; 
                    nxtRdy = 1'b1; 
                end 
            end 

            ENCODE0: begin 
                nxtRdy = 1'b0; 
                if(curBitCounter == (BitLength-1)) begin 
                    nxtState = ENCODE1; 
                    nxtBitCounter = 16'h0; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = dataBuffer[0]; 
                end 
            end 

            ENCODE1: begin 
                if(curBitCounter == (BitLength-1)) begin 
                    nxtState = ENCODE2; 
                    nxtBitCounter = 16'h0; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = dataBuffer[1]; 
                end 
            end 

            ENCODE2: begin 
                if(curBitCounter == (BitLength-1)) begin 
                    nxtState = ENCODE3; 
                    nxtBitCounter = 16'h0; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = dataBuffer[2]; 
                end 
            end 

            ENCODE3: begin 
                if(curBitCounter == (BitLength-1)) begin 
                    nxtState = ENCODE4; 
                    nxtBitCounter = 16'h0; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = dataBuffer[3]; 
                end 
            end 

            ENCODE4: begin 
                if(curBitCounter == (BitLength-1)) begin 
                    nxtState = ENCODE5; 
                    nxtBitCounter = 16'h0; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = dataBuffer[4]; 
                end 
            end 

            ENCODE5: begin 
                if(curBitCounter == (BitLength-1)) begin 
                    nxtState = ENCODE6; 
                    nxtBitCounter = 16'h0; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = dataBuffer[5]; 
                end 
            end 

            ENCODE6: begin 
                if(curBitCounter == (BitLength-1)) begin 
                    nxtState = ENCODE7; 
                    nxtBitCounter = 16'h0; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = dataBuffer[6]; 
                end 
            end 

            ENCODE7: begin 
                if(curBitCounter == (BitLength-1)) begin 
                    nxtState = ENCODE8; 
                    nxtBitCounter = 16'h0; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = dataBuffer[7]; 
                end 
            end 

            ENCODE8: begin 
                if(curBitCounter == (BitLength-1)) begin 
                    nxtState = ENCODE9; 
                    nxtBitCounter = 16'h0; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = dataBuffer[8]; 
                end 
            end 

            ENCODE9: begin 
                if(curBitCounter == (BitLength-1)) begin 
                    nxtState = ENCODEa; 
                    nxtBitCounter = 16'h0; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = dataBuffer[9]; 
                end 
            end 

            ENCODEa: begin 
                if(curBitCounter == (BitLength-1)) begin 
                    nxtState = ENCODEb; 
                    nxtBitCounter = 16'h0; 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = dataBuffer[10]; 
                end 
            end 

            ENCODEb: begin 
                nxtRdy = (curSymbolCounter == FrameLen) ? 1'b0 : 1'b1; 
                if(curBitCounter == (BitLength-1)) begin 
                    nxtBitCounter = 16'h0; 
                    if(encode) begin 
                        if(curSymbolCounter == FrameLen) begin 
                            nxtState = IDLE; 
                            nxtSymbolCounter = 8'h0; 
                            break = 1'b1; 
                        end else begin 
                            nxtState = ENCODE0;
                            dataBuffer = data12b; 
                            nxtSymbolCounter = curSymbolCounter + 1'b1; 
                        end 
                    end else begin 
                        nxtState = IDLE; 
                        nxtSymbolCounter = 8'h0; 
                    end 
                end else begin 
                    nxtBitCounter = curBitCounter + 1'b1; 
                    nxtTx = dataBuffer[11]; 
                end 
            end 

            default: begin 
                nxtState = IDLE; 
            end 

        endcase 
    end 

    reg encoding_reg; 
    assign encoding = encoding_reg; 
    always @(posedge pclk or negedge resetn) begin 
        if(~resetn) begin 
            encoding_reg <= 1'b0; 
        end else begin 
            if(curState != IDLE) begin 
                encoding_reg <= 1'b1; 
            end else begin 
                encoding_reg <= 1'b0; 
            end 
        end 
    end 

    reg [1:0] RdySync;
    always @(posedge pclk) begin 
        RdySync <= {RdySync[0], curRdy};
    end 

    assign encoderReady = ~RdySync[1] & RdySync[0]; 

endmodule 
