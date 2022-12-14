
module fen_decode(
  input logic clk,
  input logic [7:0] in_data,
  input logic in_valid,
  input logic in_sop,
  input logic in_eop,

  output reg        o_pos_valid = 0,
  output reg [3:0]  o_pos_data = 0,
  output reg        o_pos_sop = 0,
  output reg        o_pos_eop = 0,
  output reg        o_wtp = 0,
  output reg [3:0]  o_castle,
  output reg [2:0]  o_ep,
  output reg [15:0] o_hmcount,
  output reg [15:0] o_fmcount
  );

  // 1st timestep - state machine
  // delay data and valid signal

  localparam [3:0]
      fem_idle       = 4'd0,
      fem_pieces     = 4'd1,
      fem_pieces_sp  = 4'd2,
      fem_turn       = 4'd3,
      fem_turn_sp    = 4'd4,
      fem_castle     = 4'd5,
      fem_castle_sp  = 4'd6,
      fem_ep         = 4'd7,
      fem_ep_sp      = 4'd8,
      fem_hmclock    = 4'd9,
      fem_hmclock_sp = 4'd10,
      fem_fmclock    = 4'd11,
      fem_output     = 4'd12;

  wire tok_space = in_data == " ";
  reg [3:0] state = fem_idle;
  reg [7:0] state_data = 0;
  reg       state_valid = 0;
  reg       was_valid_eop = 0;

  always_ff @(posedge clk) begin
    // dleay to match decoded state
    state_data <= in_data;
    state_valid <= in_valid;
    was_valid_eop <= in_valid && in_eop;

    state <= state;
    if (in_valid & in_sop) begin
      state <= fem_pieces;
    end else if (state == fem_output) begin
        if (o_pos_eop) state <= fem_idle;
    end else if (was_valid_eop) begin
        state <= fem_output;
    end else if (in_valid) begin
        case (state)
          fem_idle: begin
            if (in_sop) state <= fem_pieces;
          end
          fem_pieces: begin
            if (tok_space) state <= fem_pieces_sp;
          end
          fem_pieces_sp: begin
            state <= fem_turn;
          end
          fem_turn: begin
            if (tok_space) state <= fem_turn_sp;
          end
          fem_turn_sp: begin
            state <= fem_castle;
          end
          fem_castle: begin
            if (tok_space) state <= fem_castle_sp;
          end
          fem_castle_sp: begin
            state <= fem_ep;
          end
          fem_ep: begin
            if (tok_space) state <= fem_ep_sp;
          end
          fem_ep_sp: begin
            state <= fem_hmclock;
          end
          fem_hmclock: begin
            if (tok_space) state <= fem_hmclock_sp;
          end
          fem_hmclock_sp: begin
            state <= fem_fmclock;
          end
          default: begin

          end
        endcase
    end
  end

  wire [6*8-1:0] white_pieces = "PNBRQK";
  wire [6*8-1:0] black_pieces = "pnbrqk";
  wire [8*8-1:0] skips = "87654321";
  //wire [9*8-1:0] ep_flags = "abcdefgh-";

  wire [5:0] tok_whitep;
  wire [5:0] tok_piecet;
  wire [7:0] tok_skip;
  wire       tok_white;
  wire       tok_piece;
  // wire [8:0] tok_ep;
  wire       tok_skips;

  genvar i;
  generate
    for(i=0;i<6;i++) begin
      assign tok_whitep[i] = in_data == white_pieces[i*8+:8];
      assign tok_piecet[i] = in_data == white_pieces[i*8+:8] | in_data == black_pieces[i*8+:8];
    end
    for(i=0;i<8;i++) begin
      assign tok_skip[i] = in_data == skips[i*8+:8];
    end
    //for(i=0;i<9;i++) begin
    //  assign tok_ep[i] = in_data == ep_flags[i*8+:8];
    //end
  endgenerate
  assign tok_white = |tok_whitep;
  assign tok_piece = |tok_piecet;
  assign tok_skips = |tok_skip;

  reg [6:0] pbuffer [64-1:0];
  // encode input tokens to our output binary values
  wire [2:0] bin_piece;
  onehot_to_bin #(.ONEHOT_WIDTH(7) ) oh2b_piece (.onehot({tok_piecet, 1'b0}), .bin(bin_piece));
  wire [2:0] bin_skip;
  onehot_to_bin #(.ONEHOT_WIDTH(8) ) oh2b_skip (.onehot(tok_skip), .bin(bin_skip));

  // Write incoming pieces/skips into buffer. Leave out '/' tokens so the output
  // side can stream out pieces consecutively. Only empty pieces have a non-zero
  // repeat. Piece order follows unicode spec.
  //   player     piece         repeat
  //   (1 bit)    (3 bits)      (3 bits)
  //    0 black   000  none     000   0
  //    1 white   001  king     111   7
  //              010  queen
  //              011  rook
  //              100  bishop
  //              101  knight
  //              110  pawn
  //              111  forbidden
  // e.g. FEN '8' encodes as 0/000/111 (black, none, 7 repeats)
  //          '1' encodes as 0/000/000 (black, none, 0 repeats)
  //          'Q' encodes as 1/010/000 (white, queen, 0 repeats)
  wire [6:0] pbuffer_writedata = {tok_white, bin_piece, bin_skip};
  wire       pbuffer_wr = (tok_piece | tok_skips) & in_valid & ((state == fem_pieces) | in_sop);
  reg  [6:0] pbuffer_wraddr = 0;
  reg  [6:0] pbuffer_rdaddr = 0;

  always_ff @(posedge clk) begin
      if (pbuffer_wr) begin
          pbuffer_wraddr <= pbuffer_wraddr + 1;
      end else if (state == fem_idle) begin
          pbuffer_wraddr <= 0;
      end

      if (pbuffer_wr) begin
         pbuffer[pbuffer_wraddr[5:0]] <= pbuffer_writedata;
      end
  end


  // write output squares by draining from pbuffer[pbuffer_rdaddr]
  // if we have a skip of n, we stall n cycles before incrementing rdaddr
  wire [2:0] rd_bin_skip;
  wire [2:0] rd_bin_piece;
  wire       rd_bin_wtp;
  reg [2:0]  rd_skip_count = 0;
  assign {rd_bin_wtp, rd_bin_piece, rd_bin_skip} = pbuffer[pbuffer_rdaddr[5:0]];

  wire last_pubffer_cycle = (pbuffer_rdaddr + 1) == pbuffer_wraddr;
  wire last_skip_cycle = rd_bin_skip == rd_skip_count;
  always_ff @(posedge clk) begin
      if (state == fem_output && !o_pos_eop) begin
        pbuffer_rdaddr <= pbuffer_rdaddr + (last_skip_cycle ? 1 : 0);
        rd_skip_count <= !last_skip_cycle ? rd_skip_count + 1 : 0;
        o_pos_valid <= 1;
        o_pos_data <= {rd_bin_wtp, rd_bin_piece};
        o_pos_sop <= pbuffer_rdaddr == 0 && (rd_skip_count == 0);
        o_pos_eop <= last_pubffer_cycle && last_skip_cycle;
      end else begin
        pbuffer_rdaddr <= 0;
        o_pos_valid <= 0;
        o_pos_eop <= 0;
        o_pos_sop <= 0;
        rd_skip_count <= 0;
      end

  end

  // handle white to play (wtp)
  always_ff @(posedge clk) begin
    if (state == fem_turn && state_valid) begin
      o_wtp <= (state_data == "w");
    end
  end

  // handle castling rights
  always_ff @(posedge clk) begin
    if (state == fem_pieces) begin
      o_castle[3:0] <= 4'b0;
    end else if (state == fem_castle && state_valid) begin
      o_castle[0] <= o_castle[0] | state_data == "K";
      o_castle[1] <= o_castle[1] | state_data == "Q";
      o_castle[2] <= o_castle[2] | state_data == "k";
      o_castle[3] <= o_castle[3] | state_data == "q";
    end
  end

  // handle ep
  always_ff @(posedge clk) begin
    if (state == fem_pieces) begin
      o_ep[2:0] <= 3'b0;
    end else if (state == fem_ep && state_valid) begin
      if (state_data == "-") begin
        o_ep[2:0] <= 3'b0;
      end else begin
        o_ep <= state_data[2:0];
      end
    end
  end

  // handle move and halfmove counters
  wire [15:0] bin_count;
  ascii_int_to_bin moves_asciibin (.clk(clk), .data(in_data[3:0]), .valid(in_valid), .reset(tok_space), .bin(bin_count));
  always_ff @(posedge clk) begin
    if (state == fem_hmclock) begin
      o_hmcount <= bin_count;
    end
    if (state == fem_fmclock) begin
      o_fmcount <= bin_count;
    end
  end

endmodule
