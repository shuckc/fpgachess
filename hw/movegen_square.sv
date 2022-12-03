
module movegen_square #(
        parameter RANK = 1,
        parameter FILE = 1
  ) (
  input logic clk,

  input logic        in_pos_valid = 0,
  input logic [3:0]  in_pos_data = 0,
  output reg  [3:0]  out_pos_data = 0,

  input logic        emit_move,
  input logic        target_square
  );

  always @(posedge clk) begin
    if (in_pos_valid) begin
      out_pos_data <= in_pos_data;
    end
  end

endmodule
