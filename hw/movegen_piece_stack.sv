
module movegen_piece_stack #(
        parameter POSITION = 1,
        parameter WIDTH = 10
  ) (
    input logic              clk,
    input logic              clear,

    input logic [WIDTH-1:0]  in_data,
    input logic              load,
    output reg  [WIDTH-1:0]  out_data = 0
  );

  always @(posedge clk) begin
    if (clear) begin
      out_data <= 0;
    end else if (load) begin
      out_data <= in_data;
    end
  end

endmodule
