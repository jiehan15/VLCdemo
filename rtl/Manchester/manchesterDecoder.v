/*
    Manchester Decoder 
    As per IEEE 802.3

    0 -> high-to-low transition 
    1 -> low-to-high transition 
*/

// global clock 12MHz

module manchesterDecoder(
    input rx,
    input clk16x, // global clock, fast clock 
    input resetn, 

    output [7:0] data_o, 
    output dataValid_o, 
    output recvErr
);
    
    // two D flip-flop to oversample the incoming data 
    // and sync them to this clock domian 
    reg [1:0] RxD_sync; 
    always @(posedge clk16x) begin 
        RxD_sync <= {RxD_sync[0], rx};
    end

    /////////////////////////////////////////////////
    // state machine 
    parameter IDLE = 8'h0; 
    parameter SYNCHIGH0 = 8'h1; 
    parameter SYNCHIGH1 = 8'h2; 
    parameter SYNCHIGH2 = 8'h3; 

    parameter SYNCLOW0 = 8'h4; 
    parameter SYNCLOW1 = 8'h5; 
    parameter SYNCLOW2 = 8'h6; 

    parameter DECODE0 = 8'h7; 
    parameter DECODE1 = 8'h8; 
    parameter DECODE2 = 8'h9; 
    parameter DECODE3 = 8'ha; 
    parameter DECODE4 = 8'hb; 
    parameter DECODE5 = 8'hc; 
    parameter DECODE6 = 8'hd; 
    parameter DECODE7 = 8'he; 
    parameter DECODE8 = 8'hf; 
    parameter DECODE9 = 8'h10; 
    parameter DECODEa = 8'h11; 
    parameter DECODEb = 8'h12; 
    parameter DECODEc = 8'h13; 
    parameter DECODEd = 8'h14; 
    parameter DECODEe = 8'h15; 
    parameter DECODEf = 8'h16; 

    parameter RECEIVED = 8'h17; 
    parameter WAITFORVALID = 8'h18; 
    parameter VERIFY = 8'h19;

    reg [7:0] curState, nxtState; 

    reg sample; 
    reg [15:0] sampleCounter; 
    reg [15:0] nextSamplePoint; 
    always @(posedge clk16x or negedge resetn) begin 
        if(~resetn) begin 
            sample <= 1'b0; 
            sampleCounter <= 16'h0; 
            nextSamplePoint <= 16'd18; // initial point 
        end else begin 
            if(curState == IDLE) begin 
                sample <= 1'b0; 
                sampleCounter <= 16'h0; 
                nextSamplePoint <= 16'd18; // initial point 
            end else begin 
                sampleCounter <= sampleCounter + 1'b1; 
                // sample at 1/4 and 3/4 clock cycle 
                if(sampleCounter == nextSamplePoint) begin 
                    sample <= 1'b1;
                    nextSamplePoint <= nextSamplePoint + 16'd40; 
                end else begin 
                    sample <= 1'b0; 
                end 
            end 
        end 
    end 

    reg [15:0] curRawData, nxtRawData; 
    reg curReceived, nxtReceived; 

    wire [7:0] data; assign data_o = data; 
    wire isPWM; 
    wire dataValid; assign dataValid_o = dataValid; 

    manDecoderComb md_comb(
        .clk(clk16x), 
        .rawdata(curRawData), 
        .en(curReceived), 
        .data_decoded(data), 
        .dataValid(dataValid), 
        .err(recvErr), 
        .isPWM(isPWM)
    );

    always @(posedge clk16x or negedge resetn) begin 
        if(~resetn) begin 
            curState <= IDLE; 
            curRawData <= 16'h0; 
            curReceived <= 1'b0; 
        end else begin 
            curState <= nxtState; 
            curRawData <= nxtRawData; 
            curReceived <= nxtReceived; 
        end 
    end 

    always @(*) begin 
        nxtState = curState; 
        nxtRawData = curRawData; 
        nxtReceived = 1'b0; 

        case(curState)
            IDLE: begin 
                if(RxD_sync[1]) begin 
                    nxtState = SYNCHIGH0; 
                    nxtRawData = 16'h0; 
                end 
            end 

            SYNCHIGH0: begin 
                if(sample) begin 
                    if(RxD_sync[1]) begin 
                        nxtState = SYNCHIGH1; 
                    end else begin 
                        nxtState = IDLE; 
                    end 
                end 
            end 

            SYNCHIGH1: begin 
                if(sample) begin 
                    if(RxD_sync[1]) begin 
                        nxtState = SYNCHIGH2; 
                    end else begin 
                        nxtState = IDLE; 
                    end 
                end 
            end 

            SYNCHIGH2: begin 
                if(sample) begin 
                    if(RxD_sync[1]) begin 
                        nxtState = SYNCLOW0; 
                    end else begin 
                        nxtState = IDLE; 
                    end 
                end 
            end 

            SYNCLOW0: begin 
                if(sample) begin 
                    if(~RxD_sync[1]) begin 
                        nxtState = SYNCLOW1; 
                    end else begin 
                        nxtState = SYNCLOW0; 
                    end 
                end 
            end 

            SYNCLOW1: begin 
                if(sample) begin 
                    if(~RxD_sync[1]) begin 
                        nxtState = SYNCLOW2; 
                    end else begin 
                        nxtState = IDLE; 
                    end 
                end 
            end 

            SYNCLOW2: begin 
                if(sample) begin 
                    if(~RxD_sync[1]) begin 
                        nxtState = DECODE0; 
                    end else begin 
                        nxtState = IDLE; 
                    end 
                end 
            end 

            // sample data (16 half bits)
            DECODE0: begin 
                if(sample) begin 
                    nxtRawData[0] = RxD_sync[1]; 
                    nxtState = DECODE1; 
                end 
            end 

            DECODE1: begin 
                if(sample) begin 
                    nxtRawData[1] = RxD_sync[1]; 
                    nxtState = DECODE2; 
                end 
            end 

            DECODE2: begin 
                if(sample) begin 
                    nxtRawData[2] = RxD_sync[1]; 
                    nxtState = DECODE3; 
                end
            end 

            DECODE3: begin 
                if(sample) begin 
                    nxtRawData[3] = RxD_sync[1]; 
                    nxtState = DECODE4; 
                end 
            end 

            DECODE4: begin 
                if(sample) begin 
                    nxtRawData[4] = RxD_sync[1]; 
                    nxtState = DECODE5; 
                end 
            end 

            DECODE5: begin 
                if(sample) begin 
                    nxtRawData[5] = RxD_sync[1]; 
                    nxtState = DECODE6; 
                end 
            end 

            DECODE6: begin 
                if(sample) begin 
                    nxtRawData[6] = RxD_sync[1]; 
                    nxtState = DECODE7; 
                end 
            end 

            DECODE7: begin 
                if(sample) begin 
                    nxtRawData[7] = RxD_sync[1]; 
                    nxtState = DECODE8; 
                end 
            end 

            DECODE8: begin 
                if(sample) begin 
                    nxtRawData[8] = RxD_sync[1]; 
                    nxtState = DECODE9; 
                end 
            end 

            DECODE9: begin 
                if(sample) begin 
                    nxtRawData[9] = RxD_sync[1]; 
                    nxtState = DECODEa; 
                end 
            end 

            DECODEa: begin 
                if(sample) begin 
                    nxtRawData[10] = RxD_sync[1]; 
                    nxtState = DECODEb; 
                end 
            end 

            DECODEb: begin 
                if(sample) begin 
                    nxtRawData[11] = RxD_sync[1]; 
                    nxtState = DECODEc; 
                end 
            end 

            DECODEc: begin 
                if(sample) begin 
                    nxtRawData[12] = RxD_sync[1]; 
                    nxtState = DECODEd; 
                end 
            end 

            DECODEd: begin 
                if(sample) begin 
                    nxtRawData[13] = RxD_sync[1]; 
                    nxtState = DECODEe; 
                end 
            end 

            DECODEe: begin 
                if(sample) begin 
                    nxtRawData[14] = RxD_sync[1]; 
                    nxtState = DECODEf; 
                end 
            end 

            DECODEf: begin 
                if(sample) begin 
                    nxtRawData[15] = RxD_sync[1]; 
                    nxtState = RECEIVED; 
                end 
            end 

            RECEIVED: begin 
                nxtReceived = 1'b1; 
                nxtState = WAITFORVALID; 
            end 

            WAITFORVALID: begin 
                nxtState = VERIFY; 
            end 

            VERIFY: begin 
                if(dataValid & ~isPWM) begin 
                    nxtState = DECODE0; 
                end else begin 
                    nxtState = IDLE; 
                end 
            end 

            default: begin 
                nxtState = IDLE; 
            end 
        endcase 
    end 

endmodule 

module manDecoderComb(
    input clk, 
    input [15:0] rawdata,
    input en, 

    output [7:0] data_decoded, 
    output dataValid, 
    output err, 
    output isPWM
); 
    integer i;  
    reg [7:0] data_comb; 
    reg dataValid_comb; 
    reg err_comb; 


    reg [7:0] pwm_comb; 
    // used to indicate if the transmitted is entered the IDLE state 

    always @(*) begin 
        if(en) begin 
            err_comb = 1'b0; 
            pwm_comb = 8'h0; 
            for(i=0; i<8;i=i+1) begin 
                if(rawdata[(i*2) +: 2] == 2'b10) begin 
                    data_comb[i] = 1'b1;
                end else if(rawdata[(i*2) +: 2] == 2'b01) begin 
                    data_comb[i] = 1'b0;
                end else begin 
                    data_comb[i] = 1'bz;
                    pwm_comb[i] = 1'b1; 
                    err_comb = 1'b1; 
                end 
            end 
            dataValid_comb = 1'b1; 
        end 
    end 

    reg [7:0] data_seq; 
    reg dataValid_seq; 
    reg err_reg; 
    reg isPWM_reg; 

    assign data_decoded = data_seq; 
    assign dataValid = dataValid_seq; 
    assign err = err_reg; 
    assign isPWM = isPWM_reg; 

    always @(posedge clk) begin 
        if(en) begin 
            data_seq <= data_comb; 
            
            if(err_comb) begin 
                err_reg <= 1'b1; 
            end else begin 
                err_reg <= 1'b0; 
            end 

            if(pwm_comb == 8'hff) begin 
                isPWM_reg <= 1'b1;
            end else begin 
                isPWM_reg <= 1'b0; 
            end 

            if(~err_comb & ~isPWM) begin 
                dataValid_seq <= dataValid_comb; 
            end else begin 
                dataValid_seq <= 1'b0; 
            end 

        end else begin 
            dataValid_seq <= 1'b0; 
            err_reg <= 1'b0; 
            isPWM_reg <= 1'b0; 
        end 
    end 

endmodule
