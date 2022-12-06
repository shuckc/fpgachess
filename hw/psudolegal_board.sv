
module psudolegal_board(
  input logic clk,

  input logic        in_pos_valid = 0,
  input logic [3:0]  in_pos_data = 0,
  input logic        in_pos_eop = 0,
  input logic        in_wtp = 0,
  input logic [3:0]  in_castle,
  input logic [2:0]  in_ep,


  // moves ouput in 20-bit UCI format: {promote, piece, from_rf, takes, to_rf}
  //  uci_move_promote 00   {0: no promotion, or queen, 1: bishop, 2: rook, 3: night}
  //  uci_move_piece   000  {none, king, queen, rook, bishop, knight, pawn}
  //  uci_move_from_r  000  rank 0-7
  //  uci_move_from_f  000  file 0-7
  //  uci_move_takes   000  {none, king, queen, rook, bishop, knight, pawn}
  //  uci_move_to_r    000  rank 0-7
  //  uci_move_to_f    000  file 0-7
  input logic       start,
  output reg        o_uci_valid = 0,
  output reg [19:0] o_uci_data = 0,
  output reg        o_uci_sop = 0,
  output reg        o_uci_eop = 0
  );


  // pack and register uci_move output
  wire [1:0] uci_move_promote;
  wire [2:0] uci_move_piece;
  wire [2:0] uci_move_from_r;
  wire [2:0] uci_move_from_f;
  wire [2:0] uci_move_takes;
  wire [2:0] uci_move_to_r;
  wire [2:0] uci_move_to_f;
  assign o_uci_data_w = {uci_move_promote, uci_move_piece, uci_move_from_r, uci_move_from_f, uci_move_takes, uci_move_to_r, uci_move_to_f};
  always @(posedge clk) begin
    o_uci_data <= o_uci_data_w;
  end

  // track the current rank/file from incoming serial form
  wire [5:0] in_pos_rf;
  movegen_rankfile movegen_rankfile (
    .clk(clk),
    .in_pos_valid( in_pos_valid ),
    .in_pos_sop(in_pos_sop),
//  .in_pos_data(in_pos_data),
    .out_rankfile(in_pos_rf)
  );

  // Instantiate the piece stack, of 2x16-items, and piece iterator 1x16 items.
  // Two stacks, one for white one for black, hold {full,piece,rank,file} in any order.
  // pushing occurs from the in_pos serial load bus when there is a piece of the
  // correct colour {piece_w, piece_b}, no change occurs on empty squares.
  // Each slot in the stack has a presence bit 'full' and a load path to the entry below.
  // When a push occurs, all populated slots shift downards.
  //
  // Both piece stacks can parallel load (depending on in_wtp) into the move-stack,
  // which shifts the contents up one-by-one as moves are generated. Loading into
  // the move_stack does not affect the contents of the white/black stacks.
  //
  //                      white   black         wtp         move_stack
  //
  //     serial in_pos ------+-----+             |  shift_piece--\ /---> uci_move_from_{r,f}
  //           in_pos_w----\ v     v /--in_pos_b |  load_pieces  | |---> uci_move_piece
  //                      [item]-[item]         _|_       +----[item]--> is_last_piece
  //                        |      +-----------|mux|------|-----/| |
  //                        +------|-----------|___|      |      | |
  //                      [item] [item]         _|_       +----[item]
  //                        |      +-----------|mux|------|-----/| |
  //                        +------|-----------|___|      |      | |
  //                      [item] [item]         _|_       +----[item]
  //                        |      +-----------|mux|------|-----/| |
  //                        +------|-----------|___|      |      | |
  //                      [item] [item]          |        +----[item]
  //
  // These stacks let us iterate the next piece to move quickly, without long
  // combinatorial paths through the 64 board squares.
  // they are built with registers rather than block rams for the unusual
  // load paths, and because we will need to push/pop the state
  // when we support board make/unmake move
  wire load_pieces;
  wire next_piece;
  wire in_pos_black = in_pos_valid && in_pos_data[3] == 1'b0 && |in_pos_data[2:0];
  wire in_pos_white = in_pos_valid && in_pos_data[3] == 1'b1 && |in_pos_data[2:0];
  wire [17*10-1:0] stack_interconnect_white;
  wire [17*10-1:0] stack_interconnect_black; // {occupied(1), pos_data(3), in_pos_rf(6)}
  wire [16*10-1:0] stack_interconnect_to_play;
  wire [16*10-1:0] stack_interconnect_to_play_o;
  assign stack_interconnect_black[9:0] = { 1'b1, in_pos_data[2:0], in_pos_rf};
  assign stack_interconnect_white[9:0] = { 1'b1, in_pos_data[2:0], in_pos_rf};
  assign stack_interconnect_to_play = load_pieces ? (in_wtp ? stack_interconnect_white[10 +: 16*10] : stack_interconnect_black[10 +: 16*10]) : stack_interconnect_to_play_o[10 +: 16*10];
  assign load_pieces = start;
  genvar i;
  generate
    for (i=0; i<16; i=i+1)
    begin: item
      movegen_piece_stack #(.POSITION(i)) movegen_piece_white (
        .clk(clk),
        .clear(in_pos_valid & in_pos_sop),
        .in_data(stack_interconnect_white[i*10 +: 9]),
        .in_push(in_pos_white & stack_interconnect_white[i*10+9]),
        .out_data(stack_interconnect_white[(i+1)*10 +: 9]),
        .out_valid(stack_interconnect_white[(i+1)*10 +9])
        );

      movegen_piece_stack #(.POSITION(i)) movegen_piece_black (
        .clk(clk),
        .clear(in_pos_valid & in_pos_sop),
        .in_data(stack_interconnect_black[i*10 +: 9]),
        .in_push(in_pos_black & stack_interconnect_black[i*10+9]),
        .out_data(stack_interconnect_black[(i+1)*10 +: 9]),
        .out_valid(stack_interconnect_black[(i+1)*10 +9])
        );

      movegen_piece_stack #(.POSITION(i)) movegen_move_stack (
        .clk(clk),
        .in_data(stack_interconnect_to_play[i*10 +: 9]),
        .in_push(load_pieces | next_piece),
        .out_data(stack_interconnect_to_play_o[i*10 +: 9]),
        .out_valid(stack_interconnect_to_play_o[i*10 + 9])
      );
    end
  endgenerate
  assign uci_move_from_f = stack_interconnect_to_play_o[0 +: 3];
  assign uci_move_from_r = stack_interconnect_to_play_o[3 +: 3];
  assign uci_move_piece = stack_interconnect_to_play_o[6 +: 3];

  assign next_piece = 1;
  //always @(posedge clk) begin
  //  o_uci_data <= o_uci_data_w;
  //end


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
