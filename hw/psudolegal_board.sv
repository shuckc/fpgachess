
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
  wire [19:0] o_uci_data_w;
  assign o_uci_data_w = {uci_move_promote, uci_move_piece, uci_move_from_r, uci_move_from_f, uci_move_takes, uci_move_to_r, uci_move_to_f};
  reg r_load_pieces_d = 0;
  always_ff @(posedge clk) begin
    o_uci_data <= o_uci_data_w;
    o_uci_valid <= stack_interconnect_to_play_o[9];
    o_uci_sop <= r_load_pieces_d;
    o_uci_eop <= !stack_interconnect_to_play_o[10+9];
    r_load_pieces_d <= load_pieces;
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
  assign stack_interconnect_to_play = load_pieces ? (in_wtp ? stack_interconnect_white[10 +: 16*10] : stack_interconnect_black[10 +: 16*10]) : {10'b0, stack_interconnect_to_play_o[10 +: 15*10]};

  assign load_pieces = start;
  genvar i;
  generate
    for (i=0; i<16; i=i+1)
    begin: item
      movegen_piece_stack #(.POSITION(i)) movegen_piece_white (
        .clk(clk),
        .clear(in_pos_valid & in_pos_sop),
        .in_data(stack_interconnect_white[i*10 +: 10]),
        .out_data(stack_interconnect_white[(i+1)*10 +: 10]),
        .load(in_pos_white & stack_interconnect_white[i*10+9])
        );

      movegen_piece_stack #(.POSITION(i)) movegen_piece_black (
        .clk(clk),
        .clear(in_pos_valid & in_pos_sop),
        .in_data(stack_interconnect_black[i*10 +: 10]),
        .out_data(stack_interconnect_black[(i+1)*10 +: 10]),
        .load(in_pos_black & stack_interconnect_black[i*10+9])
        );

      movegen_piece_stack #(.POSITION(i)) movegen_move_stack (
        .clk(clk),
        .clear(1'b0),
        .in_data(stack_interconnect_to_play[i*10 +: 10]),
        .out_data(stack_interconnect_to_play_o[i*10 +: 10]),
        .load(load_pieces | next_piece)
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
  //
  // emit_move signals a square to output valid moves the piece it holds can make.
  // depending on the piece, the piece and colour (white/black) will determine
  // which of the outputs to other squares become hot. The various interconnects
  // pass the signal to the neighbouring squares in each direction on the input lines.
  // Empty squares emit incoming moves as a valid destination by setting their square_to bit.
  // Squares occupied by self (wtp) will block and not emit. opponent squares will emit.
  // slider signals will be blocked by occupied pieces otherwise passed
  // combinatorially to the next square (worst case ripple 8).
  //
  // square_from signals this occupied square to outputing its moves
  // any square with an incoming ray outputs its target_square signal.
  //
  // ie. emit_move --> o_{dir} signals --> i_{dir} signals --> target_square
  //
  //
  // squares do not output their piece, this is done by memories clocked from
  // the serial load ports in paralell to the serial load.
  //
  // All 64 target_square bits are fed into an abritrator to iterate the psuado-valid
  // moves that can be made from the selected piece (perhaps none).
  //
  wire [63:0] square_from;   // one-hot, only 1sq holds token at once
  wire [63:0] square_to;     // multi-hot, all destination squares
  wire [63:0] square_to_arb; // one-hot after masking and HTP logic (see below)

  // convert the current cell uci_move_from coordinates from piece_stack to a
  // one-hot signal routed to the board square
  onehot_from_bin #(.WIDTH(64)) onehot_from_bin(
    .in({uci_move_from_r, uci_move_from_f}),
    .out(square_from)
  );

  // serial pos interconnect
  wire [(65*4)-1:0]pos_interconnect; // 64 squares plus unused final square output
  assign pos_interconnect[3:0] = in_pos_data;

  // board move interconnect, each following the name of the driving pins
  wire [9*8-1:0] w_pn, w_ps;

  genvar r,f;
  generate
    for (r=0; r<8; r=r+1)
    begin: rank // rows
      for (f=0; f<8; f=f+1)
      begin: file // columns
        movegen_square #(.RANK(r+1), .FILE(f+1)) movegen_square (
          .clk(clk),
          .in_pos_valid(in_pos_valid),
          .in_pos_data( pos_interconnect[(r*8+(7-f)+0)*4 +: 4]),
          .out_pos_data(pos_interconnect[(r*8+(7-f)+1)*4 +: 4]),

          // trigger for this square to emit, and signalling
          // a valid destination
          .emit_move( square_from[r*8+f] ),
          .target_square( square_to[r*8+f]),

          // interconnect signals between squares

          // pawn moves signals are not shared with king because of
          // initial double moves, ep logic, and diagonals being
          //  valid only if taking.
          // from      to
          .o_pn(w_pn[(r+1)*8 + f]),  .i_ps(w_pn[r*8 + f]),
          .o_ps(w_ps[(r+1)*8 + f]),  .i_pn(w_ps[r*8 + f]),
          .o_pne(),   .i_psw(),
          .o_pnw(),   .i_pse(),
          .o_pse(),   .i_pnw(),
          .o_psw(),   .i_pne(),
          // initial double pawn moves also use pn/ps with logic in
          // the board for files 3 and 6 to forward for an extra square.
          // going north:
          //  file 2 sends o_pn, file 3 recieves i_ps,
          //  if unoccupied, file 3 sends o_pn, file 4 recieves i_ps
          // going south,
          //  file 7 send o_ps, file 6 recieves i_pn,
          //  if unoccupied, file 6 sends o_ps, file 5 recieves i_pn

          // a sqaure recieving the pawn diagonal move signals emits if
          // it is occupied and can be taken, OR is unoccupied but the
          // ep flags indicate a pawn double move took place over our
          // square.

          // king moves, clockwise from N
          .o_kn(),    .i_ks(),
          .o_kne(),   .i_ksw(),
          .o_ke(),    .i_kw(),
          .o_kse(),   .i_knw(),
          .o_ks(),    .i_kn(),
          .o_ksw(),   .i_kne(),
          .o_kw(),    .i_ke(),
          .o_knw(),   .i_kse(),

          // slide out rays (used by queen, rook, bishop), clockwise from N
          .o_sn(),    .i_ss(),
          .o_sne(),   .i_ssw(),
          .o_se(),    .i_sw(),
          .o_sse(),   .i_snw(),
          .o_ss(),    .i_sn(),
          .o_ssw(),   .i_sne(),
          .o_sw(),    .i_se(),
          .o_snw(),   .i_sse(),

          // knight L-moves, these skip the intermediate squares
          // TODO: knights

          // 4-bit castelling rights for KQkq are input to all squares,
          // but only used by king squares e1 e8. If the rights are present,
          // and the king's moves are being examined (emit_move), they output
          // the o_castle_e/w signals along the row. Adjacent squares pass
          // the signal if they are *empty*.
          // UCI standard uses the src/dest square of the king to notate
          // castling, ie. e1c1,e1g1,e8c8,e8g8 so we terminate the signal at dest.
          // Rooks need not emit on the castle_e/w lines since they must be in
          // place or the casteling rights would be lost, and there are no
          // intermediate squares between them and the destination square.
          .i_castle_rights(in_castle),
          .o_castle_e(),     .i_castle_w(),
          .o_castle_w(),     .i_castle_e(),

          // white to play
          .wtp(in_wtp)
        );
        // assign square_from[r*8+f] = movegen_square;
      end

      assign w_pn[0 + r] = 0; // no incoming N
      assign w_ps[64 + r] = 0; // no incoming S

    end
  endgenerate


  reg [63:0] square_base = 0;

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
