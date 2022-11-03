
module ascii_int_to_bin #(
        parameter BIN_WIDTH = 16
    ) (
    input         clk,
    input  [3:0]  data,
    input         valid,
    input         reset,
    output reg [BIN_WIDTH-1:0] bin
);

    wire [BIN_WIDTH-1:0] extend_data = {{BIN_WIDTH-4{1'b0}}, data};

    always_ff @(posedge clk) begin
        if (valid & reset) begin
            bin <= 0;
        end else if (valid) begin
            bin <= (bin * 8'd10) + extend_data;
        end
    end

endmodule
