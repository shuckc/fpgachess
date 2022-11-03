import cocotb
import chess
import logging

from cocotb.triggers import Timer, Event, RisingEdge, FallingEdge, ReadOnly
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.binary import BinaryValue
from .drivers import StreamDriver, StreamReceiver


class FENDriver(StreamDriver):
    """
    FEN strings need a length-aware transport as the final field
    is an ascii digit length field, which could have more digits.
    Over a UART you could send a linebreak to indicate the end.
    """

    async def send(self, fenstr: str):
        # validates or fires exception
        chess.Board(fenstr)
        bs = fenstr.encode()
        await super().send(bs)


@cocotb.test()
async def test_fen_decode(dut):
    await cocotb.start(Clock(dut.clk, 1000).start())

    fd = FENDriver(dut.clk, dut.valid, dut.data, dut.sop, dut.eop)
    rcv = StreamReceiver(dut.clk, dut.pos_valid, dut.pos_data, dut.pos_sop, dut.pos_eop)
    await Timer(5, units="ns")
    await RisingEdge(dut.clk)  # wait for falling edge/"negedge"

    await fd.send("8/5k2/8/8/5q2/3B4/8/4K3 w - - 0 29")
    bs = await rcv.recv()
    assert dut.o_hmcount.value == 0, "halfmove is not 0"
    assert dut.o_fmcount.value == 29, "fullmove is not 29"
    assert dut.o_wtp.value == 1, "expected white to play"
    assert dut.o_castle.value == 0, "castling rights not empty"
    assert dut.o_ep.value == 0, "no empassant"
    #  K Q R B N P   +0 black (lower case)
    #  1 2 3 4 5 6   +8 white (upper case)
    assert len(bs) == 64
    expected = (
        b""
        + b"\x00\x00\x00\x00\x00\x00\x00\x00"
        + b"\x00\x00\x00\x00\x00\x01\x00\x00"
        + b"\x00\x00\x00\x00\x00\x00\x00\x00"
        + b"\x00\x00\x00\x00\x00\x00\x00\x00"
        + b"\x00\x00\x00\x00\x00\x02\x00\x00"
        + b"\x00\x00\x00\x0c\x00\x00\x00\x00"
        + b"\x00\x00\x00\x00\x00\x00\x00\x00"
        + b"\x00\x00\x00\x00\x09\x00\x00\x00"
    )
    for i in range(64):
        assert bs[i] == expected[i], f"at cell {i} expected {expected[i]}"
    await Timer(20, units="ns")
