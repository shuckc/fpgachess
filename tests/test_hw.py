from cocotb_test.simulator import run, Icarus
from cocotb_test import simulator


class IcarusAutoTimescale(Icarus):
    def compile_command(self):
        with open(self.sim_dir + "/cmds.f", "w") as f:
            f.write("+timescale+1ns/1ns\n")
        self.compile_args.extend(["-f", self.sim_dir + "/cmds.f"])
        return super().compile_command()


# simulator.Icarus = IcarusAutoTimescale

def test_fen_decode():
    run(
        verilog_sources=[
            "hw/fen_decode.sv",
            "hw/ascii_int_to_bin.sv",
            "hw/onehot_to_bin.v",
        ],
        toplevel="fen_decode",
        module="cocotb_fen_decode",
    )

def test_psudo_legal_moves():
    run(
        verilog_sources=[
            "hw/onehot_to_bin.v",
            "hw/onehot_from_bin.v",
            "hw/psudolegal_board.sv",
            "hw/movegen_square.sv",
            "hw/movegen_lookup_output.sv",
            "hw/movegen_rankfile.sv",
            "hw/movegen_piece_stack.sv",
            "hw/arbiter.v",
        ],
        toplevel="psudolegal_board",
        module="cocotb_psudolegal_board",
        waves=True,
    )


