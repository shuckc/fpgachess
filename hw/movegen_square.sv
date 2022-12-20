
module movegen_square #(
        parameter RANK = 1,
        parameter FILE = 1
  ) (
  input logic clk,

  input logic        in_pos_valid = 0,
  input logic [3:0]  in_pos_data = 0,
  output wire  [3:0] out_pos_data,

  input logic        i_ep_file,
  input logic [3:0]  i_castle_rights,

  // pawn moves
  output        o_pn,
  output        o_ps,
  output        o_pne_nw,
  output        o_pse_sw,
  input logic   i_pn,
  input logic   i_pne,
  input logic   i_pse,
  input logic   i_ps,
  input logic   i_psw,
  input logic   i_pnw,

  // king moves
  output        o_kn,
  output        o_kne,
  output        o_ke,
  output        o_kse,
  output        o_ks,
  output        o_ksw,
  output        o_kw,
  output        o_knw,
  input logic   i_ks,
  input logic   i_ksw,
  input logic   i_kw,
  input logic   i_knw,
  input logic   i_kn,
  input logic   i_kne,
  input logic   i_ke,
  input logic   i_kse,

  // slider moves
  output        o_sn,
  output        o_sne,
  output        o_se,
  output        o_sse,
  output        o_ss,
  output        o_ssw,
  output        o_sw,
  output        o_snw,
  input logic   i_ss,
  input logic   i_ssw,
  input logic   i_sw,
  input logic   i_snw,
  input logic   i_sn,
  input logic   i_sne,
  input logic   i_se,
  input logic   i_sse,

  // knight moves
  output        o_nnne,
  output        o_nnnw,
  output        o_nsse,
  output        o_nssw,
  output        o_neen,
  output        o_nees,
  output        o_nwwn,
  output        o_nwws,

  input logic   i_nsse,
  input logic   i_nssw,
  input logic   i_nnne,
  input logic   i_nnnw,
  input logic   i_nwwn,
  input logic   i_nwws,
  input logic   i_neen,
  input logic   i_nees,

  // castle
  output        o_castle_e,
  output        o_castle_w,
  input logic   i_castle_e,
  input logic   i_castle_w,


  // control signals
  input logic   emit_move,
  output        target_square,
  input logic   load_attackers,

  input logic   wtp
  );

  // serial data clock through
  reg [3:0] pos = 0;
  reg       is_attacked = 0;

  always @(posedge clk) begin
    if (in_pos_valid) begin
      pos <= in_pos_data;
    end

    if (load_attackers) begin
      is_attacked <=  i_pne | i_pse | i_psw | i_pnw |
                      i_kn | i_kne | i_ke | i_kse | i_ks | i_ksw | i_kw | i_knw |
                      i_ss | i_sn | i_sw | i_se | i_ssw | i_snw | i_sne | i_sse |
                      i_nsse | i_nssw | i_nnne | i_nnnw | i_neen | i_nees | i_nwwn | i_nwws;
    end

  end
  assign out_pos_data = pos;

  // square flags
  wire [2:0] piece = pos[2:0];
  wire sq_occup = |piece;
  wire sq_empty = pos == 4'h0;
  wire sq_play  = sq_occup && pos[3] == wtp;
  wire sq_oppos = sq_occup && pos[3] != wtp;


  //  K Q R B N P
  //  1 2 3 4 5 6   +0 black (lower case)
  //  9 A B C D E   +8 white (upper case)
  assign p_king   = piece == 3'h1;
  assign p_queen  = piece == 3'h2;
  assign p_rook   = piece == 3'h3;
  assign p_bishop = piece == 3'h4;
  assign p_knight = piece == 3'h5;

  wire p_white_pawn = pos == 4'hE;
  wire p_black_pawn = pos == 4'h6;

  wire emit_attack = sq_oppos & load_attackers;

  // pawn moves out (direction depends on colour!)
  wire pn = (emit_move & p_white_pawn);
  assign o_pn  = pn || (RANK == 3 & i_ps & sq_empty);   // pn | double-move
  assign o_pne_nw = pn || (emit_attack & p_white_pawn); // pn | attackers

  wire ps = (emit_move & p_black_pawn);
  assign o_ps  = ps || (RANK == 6 & i_pn & sq_empty);   // ps | double-move
  assign o_pse_sw = ps || (emit_attack & p_black_pawn); // ps | attackers

  // king moves out
  wire k = (emit_move || emit_attack) & p_king;
  assign o_kn  = k;
  assign o_kne = k;
  assign o_ke  = k;
  assign o_kse = k;
  assign o_ks  = k;
  assign o_ksw = k;
  assign o_kw  = k;
  assign o_knw = k;

  // sliders out, with combinatorial pass thru if empty
  wire slide_hver = (emit_move || emit_attack) & (p_queen | p_rook);
  wire slide_diag = (emit_move || emit_attack) & (p_queen | p_bishop);
  assign o_sn  = slide_hver | (sq_empty & i_ss);
  assign o_ss  = slide_hver | (sq_empty & i_sn);
  assign o_se  = slide_hver | (sq_empty & i_sw);
  assign o_sw  = slide_hver | (sq_empty & i_se);
  assign o_sne = slide_diag | (sq_empty & i_ssw);
  assign o_sse = slide_diag | (sq_empty & i_snw);
  assign o_ssw = slide_diag | (sq_empty & i_sne);
  assign o_snw = slide_diag | (sq_empty & i_sse);

  // knight out
  wire n = (emit_move || emit_attack) & p_knight;
  assign o_nnne = n;
  assign o_nnnw = n;
  assign o_nssw = n;
  assign o_nsse = n;
  assign o_nwwn = n;
  assign o_nwws = n;
  assign o_neen = n;
  assign o_nees = n;

  // castling
  // we propagate castle signals right out to the edge of the board
  // but they will get pruned back to b/g files where they are last used
  wire castle_move;
  generate
    if (RANK == 1 && FILE == 5) begin // e1_king square
      assign o_castle_w = i_castle_rights[2] & emit_move & !is_attacked; // white queenside
      assign o_castle_e = i_castle_rights[3] & emit_move & !is_attacked; // white kingside
      assign castle_move = 0;
    end
    else if (RANK == 8 && FILE == 5) begin // e8 king square
      assign o_castle_w = i_castle_rights[0] & emit_move & !is_attacked; // black queenside
      assign o_castle_e = i_castle_rights[1] & emit_move & !is_attacked; // black kingside
      assign castle_move = 0;
    end
    else if (RANK == 1) begin // 1_rank
      assign o_castle_w = sq_empty && i_castle_e;
      assign o_castle_e = sq_empty && i_castle_w;
      assign castle_move = (FILE == 7 && sq_empty && i_castle_w) | (FILE == 3 && sq_empty && i_castle_e);
    end
    else if (RANK == 8) begin // 8_rank
      assign o_castle_w = sq_empty && i_castle_e;
      assign o_castle_e = sq_empty && i_castle_w;
      assign castle_move = (FILE == 7 && sq_empty && i_castle_w) | (FILE == 3 && sq_empty && i_castle_e);
    end
    else begin : not_king_row
      assign o_castle_e = 0;
      assign o_castle_w = 0;
      assign castle_move = 0;
    end
  endgenerate

  // pieces moving here
  assign pawn_move = (i_pn | i_ps) & sq_empty;
  assign pawn_take = (i_pne | i_pse | i_psw | i_pnw) & sq_oppos;
  // if  wtp, ep indicates a black move, RANK == 6 is the ep capture square
  // if !wtp, ep indicates a white move, RANK == 3 is the ep capture square
  assign pawn_ep   = (((i_pne | i_pnw) && sq_empty && RANK == 3) |
                      ((i_pse | i_psw) && sq_empty && RANK == 6))
                    && i_ep_file;

  assign king_move = (i_kn | i_kne | i_ke | i_kse | i_ks | i_ksw | i_kw | i_knw) & (sq_empty | sq_oppos);
  assign slide_move = (i_ss | i_sn | i_sw | i_se | i_ssw | i_snw | i_sne | i_sse) & (sq_empty | sq_oppos);
  assign knight_move = (i_nsse | i_nssw | i_nnne | i_nnnw | i_neen | i_nees | i_nwwn | i_nwws) & (sq_empty | sq_oppos);
  assign target_square = pawn_move || pawn_take || pawn_ep || knight_move || slide_move || king_move || castle_move;

endmodule
