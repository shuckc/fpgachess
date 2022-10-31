
module test_top (
    input  wire [7:0] data,
    input  wire       clk,
    input  wire       sop,
    input  wire       eop,
    input  wire       valid
);

    wire        pos_valid;
    wire [3:0]  pos_data;
    wire        pos_sop;
    wire        pos_eop;
    wire        o_wtp;
    wire [3:0]  o_castle;
    wire [2:0]  o_ep;
    wire [15:0] o_hmcount;
    wire [15:0] o_fmcount;

    fen_decode UUT (
        .clk(clk),
        .in_data(data),
        .in_sop(sop),
        .in_eop(eop),
        .in_valid(valid),
        .o_pos_valid(pos_valid),
        .o_pos_data(pos_data),
        .o_pos_sop(pos_sop),
        .o_pos_eop(pos_eop),
        .o_wtp(o_wtp),
        .o_castle(o_castle),
        .o_ep(o_ep),
        .o_hmcount(o_hmcount),
        .o_fmcount(o_fmcount)
    );


`ifdef COCOTB_SIM
initial begin
  $dumpfile ("sim_build/test_fen_decode.vcd");
  $dumpvars (0);
  #1;
end
`endif

endmodule