
module onehot_to_bin #(
        parameter ONEHOT_WIDTH = 16
    ) (
    input  [ONEHOT_WIDTH-1:0]  onehot,
    output [BIN_WIDTH-1:0]     bin);

localparam BIN_WIDTH = $clog2(ONEHOT_WIDTH-1);

genvar i,j;
generate
    for (j=0; j<BIN_WIDTH; j=j+1)
    begin : jl
        wire [ONEHOT_WIDTH-1:0] tmp_mask;
        for (i=0; i<ONEHOT_WIDTH; i=i+1)
        begin : il
            assign tmp_mask[i] = i[j];
        end
        assign bin[j] = |(tmp_mask & onehot);
    end
endgenerate

endmodule
