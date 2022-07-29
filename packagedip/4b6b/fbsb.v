
module fourBit2SixBit(
    input [3:0] fourbitin,
    output [5:0] sixbitout
);
    reg [5:0] sixbit; 
    assign sixbitout = sixbit; 

    always @(*) begin
        case(fourbitin)
            4'b0000: sixbit = 6'b001110;
            4'b0001: sixbit = 6'b001101;
            4'b0010: sixbit = 6'b010011;
            4'b0011: sixbit = 6'b010110;

            4'b0100: sixbit = 6'b010101;
            4'b0101: sixbit = 6'b100011;
            4'b0110: sixbit = 6'b100110;
            4'b0111: sixbit = 6'b100101;

            4'b1000: sixbit = 6'b011001;
            4'b1001: sixbit = 6'b011010;
            4'b1010: sixbit = 6'b011100;
            4'b1011: sixbit = 6'b110001;

            4'b1100: sixbit = 6'b110010;
            4'b1101: sixbit = 6'b101001;
            4'b1110: sixbit = 6'b101010;
            4'b1111: sixbit = 6'b101100;
            default: sixbit = 6'bzzzzzz; 
        endcase 
    end

endmodule 

module SixBit2fourBit(
    input [5:0] sixbitin,
    output [3:0] fourbitout
);

    reg [3:0] fourbit; 
    assign fourbitout = fourbit; 

    always @(*) begin 
        case(sixbitin)
            6'b001110: fourbit = 4'h0; 
            6'b001101: fourbit = 4'h1; 
            6'b010011: fourbit = 4'h2; 
            6'b010110: fourbit = 4'h3; 

            6'b010101: fourbit = 4'h4; 
            6'b100011: fourbit = 4'h5; 
            6'b100110: fourbit = 4'h6; 
            6'b100101: fourbit = 4'h7; 

            6'b011001: fourbit = 4'h8; 
            6'b011010: fourbit = 4'h9; 
            6'b011100: fourbit = 4'ha; 
            6'b110001: fourbit = 4'hb; 

            6'b110010: fourbit = 4'hc; 
            6'b101001: fourbit = 4'hd; 
            6'b101010: fourbit = 4'he; 
            6'b101100: fourbit = 4'hf; 
            default: fourbit = 4'hz; 
        endcase
    end 

endmodule 
