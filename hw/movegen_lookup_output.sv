
module movegen_lookup_output(
  input logic clk,

  input logic        in_pos_valid = 0,
  input logic [3:0]  in_pos_data = 0,
  input logic        in_pos_sop = 0,

  input logic [5:0]  lookup_rankfile,
  output [3:0]       out_piece
  );

  reg was_in_pos_data_sop = 0;
  always @(posedge clk) begin
    if (in_pos_valid) begin
      was_in_pos_data_sop <= in_pos_sop;
    end
  end

  reg [3:0] out_piece_r = 0;
  assign out_piece = out_piece_r;


endmodule
