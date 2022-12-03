
module psudolegal_board(
  input logic clk,

  input logic        in_pos_valid = 0,
  input logic [3:0]  in_pos_data = 0,
  input logic        in_pos_eop = 0,
  input logic        in_wtp = 0,
  input logic [3:0]  in_castle,
  input logic [2:0]  in_ep,


  // moves ouput in 20-bit UCI format: {prom, piece_moved, from_3r3f, piece_taken, to_3r3f}
  //  uci_promotion     00   {0: no promotion, or queen, 1: bishop, 2: rook, 3: night}
  //  uci_piece_moved   000  {none, king, queen, rook, bishop, knight, pawn}
  //  uci_moved_from_r  000  rank 0-7
  //  uci_moved_from_f  000  file 0-7
  //  uci_piece_taken   000  {none, king, queen, rook, bishop, knight, pawn}
  //  uci_moved_to_r    000  rank 0-7
  //  uci_moved_to_f    000  file 0-7
  input logic       start = 0,
  output reg        o_uci_valid = 0,
  output reg [19:0] o_uci_data = 0,
  output reg        o_uci_sop = 0,
  output reg        o_uci_eop = 0
  );


  // instantiate the square modules.
  // in_pos_data is a serial load that shifts through each square in turn,
  // so no routing logic/muxes required

  // move_skewer is a token to output a squares moves.
  // Each square compares the piece it holds, if any, to the in_wtp signal.
  // non-playing squares pass their move_skewer (perhaps combinatorially)
  // to the next sqaure. playing squares accept the token, and retain until all their
  // moves are output, then pass it to the next square.
  //
  // square_from is high when this square is outputing its moves
  // square_to is high when this square is a destination of the active square.
  //
  // squares do not output their piece, this is done by memories clocked from
  // the serial load ports in paralell to the serial load.

  wire [63:0] square_from;   // one-hot, only 1sq holds token at once
  wire [63:0] square_to;     // multi-hot, all destination squares
  wire [63:0] square_to_arb; // one-hot after masking and HTP logic (see below)

  wire [(65*4)-1:0]pos_interconnect; // 64 squares plus unused final square output
  assign pos_interconnect[3:0] = in_pos_data;

  // connect the serial board loading bus to each square
  genvar r,f;
  generate
    for (r=0; r<8; r=r+1)
    begin: rank
      for (f=0; f<8; f=f+1)
      begin: file
        movegen_square #(.RANK(r), .FILE(f)) movegen_square (
          .clk(clk),
          .in_pos_valid(in_pos_valid),
          .in_pos_data( pos_interconnect[(r*8+f+0)*4 +: 4]),
          .out_pos_data(pos_interconnect[(r*8+f+1)*4 +: 4]),

          .emit_move( square_from[r*8+f] ),
          .target_square( square_to[r*8+f])
        );

        // always @(posedge sysclk) begin
        //    temp[i] <= 1'b0;
        //end

        // assign square_from[r*8+f] = movegen_square;
      end
    end
  endgenerate


  arbiter #(.WIDTH(64)) arbiter_target (
    .base(square_base),
    .req(square_to),
    .grant(square_to_arb)
  );

  // connect serial board loading bus to the target square->target piece RAM

  wire [3:0]  uci_moved_to_rank;
  wire [3:0]  uci_moved_to_file;
  wire [3:0]  uci_piece_taken;

  movegen_lookup_output movegen_lookup (
    .clk(clk),
    .in_pos_valid(in_pos_valid),
    .in_pos_data(in_pos_data),
    .in_pos_sop(in_pos_sop),

    .lookup_rankfile({uci_moved_to_rank, uci_moved_to_file}),
    .out_piece(uci_piece_taken)
  );

  reg was_in_pos_data_eop = 0;
  always @(posedge clk) begin
    if (in_pos_valid) begin
      was_in_pos_data_eop <= in_pos_eop;
    end
  end




endmodule
