
module fen_decode(
  input logic clk,
  input logic [7:0] in_data,
  input logic in_valid,
  input logic in_sop,
  input logic in_eop,

  output reg        o_valid = 0,
  output reg [3:0]  o_pdata,
  output reg        o_turn,
  output reg [3:0]  o_castle,
  output reg [2:0]  o_ep,
  output reg [15:0] o_hmcount,
  output reg [15:0] o_fmcount
  );

  timeunit 1s;
  timeprecision 1ns;

  wire [6*8-1:0] white_pieces = "PRNBQK";
  wire [6*8-1:0] black_pieces = "prnbqk";
  wire [8*8-1:0] skips = "12345678";
  wire [5*8-1:0] castle_flags = "KQkq-";
  wire [9*8-1:0] ep_flags = "abcdefg-";

  wire tok_nextrank = in_data == "/";
  wire tok_space = in_data == " ";
  wire [5:0] tok_whitep;
  wire [5:0] tok_blackp;
  wire [5:0] tok_piecet;
  wire [7:0] tok_skip;
  wire       tok_white;
  wire       tok_black;
  wire       tok_piece;
  wire [5:0] tok_castle;
  wire [7:0] tok_ep;
  wire       tok_skips;
  wire [3:0] tok_a2d_num = in_data[3:0]; // in_data[7:0] - "0";

  genvar i;
  generate
    for(i=0;i<6;i++) begin
      assign tok_whitep[i] = in_data == white_pieces[i*8+:8];
      assign tok_blackp[i] = in_data == black_pieces[i*8+:8];
      assign tok_piecet[i] = in_data == white_pieces[i*8+:8] | in_data == black_pieces[i*8+:8];
    end
    for(i=0;i<8;i++) begin
      assign tok_skip[i] = in_data == skips[i*8+:8];
      assign tok_ep[i] = in_data == ep_flags[i*8+:8];
    end
    for (i=0;i<5;i++) begin
      assign tok_castle[i] = in_data == castle_flags[i*8+:8];
    end
  endgenerate
  assign tok_white = |tok_whitep;
  assign tok_black = |tok_blackp;
  assign tok_piece = |tok_piecet;
  assign tok_skips = |tok_skip;

  localparam [3:0]
      fem_idle = 3'd0,
      fem_pieces = 3'd1,
      fem_turn = 3'd2,
      fem_castle = 3'd3,
      fem_ep = 3'd4,
      fem_hmclock = 3'd5,
      fem_fmclock = 3'd6,
      fem_output = 3'd7;

  reg [3:0] state = fem_idle;
  reg [4:0] pbuffer [64-1:0];

  always_ff @(posedge clk) begin
    state <= state;
    if (in_valid & in_sop) begin
      state <= fem_pieces;
    end else if (state == fem_output) begin
        if (pbuffer_wraddr == pbuffer_rdaddr) state <= fem_idle;
    end else if (in_valid) begin
        case (state)
          fem_pieces: begin
            if (tok_space) state <= fem_turn;
          end
          fem_turn: begin
            if (tok_space) state <= fem_castle;
          end
          fem_castle: begin
            if (tok_space) state <= fem_ep;
          end
          fem_ep: begin
            if (tok_space) state <= fem_hmclock;
          end
          fem_hmclock: begin
            if (tok_space) state <= fem_fmclock;
          end
          fem_fmclock: begin
            if (in_eop) state <= fem_output;
          end
        endcase
    end
  end

  // encode input tokens to our output binary values
  wire [2:0] bin_piece;
  onehot_to_bin #(.ONEHOT_WIDTH(6) ) oh2b_piece (.onehot(tok_piecet), .bin(bin_piece));
  wire [3:0] bin_skip = tok_a2d_num;

  // write incoming pieces/skips into buffer. We leave out '/' tokens so the output
  // side can stream out pieces consecutively
  wire [4:0] pbuffer_writedata = {tok_piece, tok_white, bin_piece} | {1'b0, tok_skip};
  wire       pbuffer_wr = (tok_piece | tok_skips) & in_valid & ((state == fem_pieces) | in_sop);
  reg  [4:0] pbuffer_wraddr = 0;
  reg  [4:0] pbuffer_rdaddr = 0;

  always_ff @(posedge clk) begin
      if (pbuffer_wr) begin
          pbuffer_wraddr <= pbuffer_wraddr + 1;
      end else if (state == fem_idle) begin
          pbuffer_wraddr <= 0;
      end

      if (pbuffer_wr) begin
         pbuffer[pbuffer_wraddr] <= pbuffer_wraddr;
      end
  end


  // write output squares by draining from pbuffer[pbuffer_rdaddr]
  // if we have a skip of n, we stall n cycles before incrementing rdaddr
  always_ff @(posedge clk) begin

      if (state == fem_output) begin
        pbuffer_rdaddr <= pbuffer_rdaddr + 1;
        o_valid <= 1;

      end else begin
        pbuffer_rdaddr <= 0;
        o_valid <= 0;
      end

  end

  // handle the move and halfmove counters
  wire [15:0] bin_count;
  ascii_int_to_bin moves_asciibin (.clk(clk), .data(in_data[3:0]), .valid(in_valid), .reset(tok_space), .bin(bin_count));
  reg was_fmclock = 0; // comp for delay in moves_asciibin
  reg was_hmclock = 0;
  always_ff @(posedge clk) begin
    was_fmclock <= (state == fem_fmclock);
    was_hmclock <= (state == fem_hmclock);
    if (was_hmclock) begin
      o_hmcount <= bin_count;
    end
    if (was_fmclock) begin
      o_fmcount <= bin_count;
    end
  end

endmodule
