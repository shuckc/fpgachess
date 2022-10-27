`timescale 1ns / 1ps

module ascii_int_to_bin #(
        parameter BIN_WIDTH = 16
    ) (
    input         clk,
    input  [3:0]  data,
    input         valid,
    input         reset,
    output reg [BIN_WIDTH-1:0] bin
);

    always_ff @(posedge clk) begin
        if (valid & reset) begin
            bin <= 0;
        end else if (valid) begin
            bin <= (bin * 10) + data;
        end
    end

endmodule
