
module movegen_rankfile (
  input logic        clk,
  input logic        in_pos_valid,
  input logic        in_pos_sop,
  output wire [5:0]  out_rankfile
  );

  reg [5:0] r_rankfile_bin = 0;

  // each valid cycle moves us to the next square.
  // outputs the rank/file indexed by the expected ordering of a FEN string,
  // ie. a8,b8,c8,d8,e8,f8,g8,h8,a7,..,h7,a6,..,h6, ... ,a1,b1,..,g1,h1

  // file cycles 0-7, rank moves every 8. This is
  // simply a 6 bit counter.
  always @(posedge clk) begin
    if (in_pos_valid && in_pos_sop) begin
      r_rankfile_bin <= 0;
    end else begin
      r_rankfile_bin <= r_rankfile_bin + in_pos_valid;
    end
  end

  // combinatorial output probably OK - I don't want to retime the in_pos bus
  // for this calculation, since fan out is direct into
  // registers anyway
  wire [5:0] rankfile_bin = in_pos_sop ? 6'b0 : r_rankfile_bin + in_pos_valid;

  // the file order is conventional, so we can pass through those bits
  // ranks need to be reversed, ie descending from 7
  // at this width it will pack into LUTs rather than another adder chain
  assign out_rankfile = {{ 3'd7 - rankfile_bin[5:3], rankfile_bin[2:0] }};

endmodule
