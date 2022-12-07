
module movegen_rankfile (
  input logic        clk,
  input logic        in_pos_valid,
  input logic        in_pos_sop,
  output wire [5:0]  out_rankfile
  );

  reg [5:0] r_rankfile = 0;

  // each valid cycle moves to the next square
  // file cycles 0-7, rank moves every 8. This is
  // simply a 6 bit counter.
  always @(posedge clk) begin
    if (in_pos_valid && in_pos_sop) begin
      r_rankfile <= 0;
    end else begin
      r_rankfile <= r_rankfile + in_pos_valid;
    end
  end

  // combinatorial output probably OK - I don't want to retime the in_pos bus
  // for this calculation, since fan out is direct into
  // registers anyway
  assign out_rankfile = r_rankfile + (in_pos_valid & !in_pos_sop);

endmodule
