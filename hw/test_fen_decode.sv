
module test_top (
    input  wire [7:0] data,
    input  wire       clk,
    input  wire       sop,
    input  wire       eop,
    input  wire       valid
);

    wire        o_valid;
    wire [3:0]  o_pdata;
    wire        o_turn;
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
        .o_valid(o_valid),
        .o_pdata(o_pdata),
        .o_turn(o_turn),
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