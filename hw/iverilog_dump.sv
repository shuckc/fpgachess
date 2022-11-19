
module iverilog_dump();

`ifdef COCOTB_SIM
initial begin
  $dumpfile("sim_build/last_test.lxt");
  $dumpvars(0);
end
`endif

endmodule
