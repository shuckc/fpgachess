import cocotb
import chess
import logging

from cocotb.triggers import Timer, Event, RisingEdge, FallingEdge, ReadOnly
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.binary import BinaryValue

from drivers import StreamDriver, StreamReceiver, IdleToggler


class FENDriver(StreamDriver):
    """
    FEN strings need a length-aware transport as the final field
    is an ascii digit length field, which could have more digits.
    Over a UART you could send a linebreak to indicate the end.
    """

    async def send(self, fenstr: str, **kwargs):
        # validates or fires exception
        chess.Board(fenstr)
        bs = fenstr.encode()
        await super().send(bs, **kwargs)


@cocotb.test()
async def test_fen_decode(dut):
    await cocotb.start(Clock(dut.clk, 1000).start())

    fd = FENDriver(dut.clk, dut.in_valid, dut.in_data, dut.in_sop, dut.in_eop)
    rcv = StreamReceiver(
        dut.clk, dut.o_pos_valid, dut.o_pos_data, dut.o_pos_sop, dut.o_pos_eop
    )
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
    await Timer(2000, units="ns")


@cocotb.test()
async def test_fen_opening(dut):
    await cocotb.start(Clock(dut.clk, 1000).start())
    fd = FENDriver(dut.clk, dut.in_valid, dut.in_data, dut.in_sop, dut.in_eop)
    rcv = StreamReceiver(
        dut.clk, dut.o_pos_valid, dut.o_pos_data, dut.o_pos_sop, dut.o_pos_eop
    )
    await Timer(5, units="ns")
    await RisingEdge(dut.clk)  # wait for falling edge/"negedge"

    await fd.send(
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", idler=IdleToggler()
    )
    bs = await rcv.recv()
    assert dut.o_hmcount.value == 0, "halfmove is not 0"
    assert dut.o_fmcount.value == 1, "fullmove is not 29"
    assert dut.o_wtp.value == 1, "expected white to play"
    assert dut.o_castle.value == 15, "castling rights not empty"
    assert dut.o_ep.value == 0, "no empassant"
    #  K Q R B N P
    #  1 2 3 4 5 6   +0 black (lower case)
    #  9 A B C D E   +8 white (upper case)
    assert len(bs) == 64
    expected = (
        b""
        + b"\x03\x05\x04\x02\x01\x04\x05\x03"
        + b"\x06\x06\x06\x06\x06\x06\x06\x06"
        + b"\x00\x00\x00\x00\x00\x00\x00\x00"
        + b"\x00\x00\x00\x00\x00\x00\x00\x00"
        + b"\x00\x00\x00\x00\x00\x00\x00\x00"
        + b"\x00\x00\x00\x00\x00\x00\x00\x00"
        + b"\x0E\x0E\x0E\x0E\x0E\x0E\x0E\x0E"
        + b"\x0B\x0D\x0C\x0A\x09\x0C\x0D\x0B"
    )
    for i in range(64):
        assert bs[i] == expected[i], f"at cell {i} expected {expected[i]}"
    await Timer(2000, units="ns")


@cocotb.test()
async def test_longest_fenstring(dut):

    await cocotb.start(Clock(dut.clk, 1000).start())
    fd = FENDriver(dut.clk, dut.in_valid, dut.in_data, dut.in_sop, dut.in_eop)
    rcv = StreamReceiver(
        dut.clk, dut.o_pos_valid, dut.o_pos_data, dut.o_pos_sop, dut.o_pos_eop
    )
    await Timer(5, units="ns")
    await RisingEdge(dut.clk)  # wait for falling edge/"negedge"

    # 32 pieces, 64 squares, alternate
    # worst case fill of the internal FIFO
    await fd.send(
        "r1n1b1q1/k1b1n1r1/p1p1p1p1/p1p1p1p1/P1P1P1P1/P1P1P1P1/R1N1B1Q1/K1B1N1R1 w KQkq - 0 1",
        idler=IdleToggler(),
    )
    bs = await rcv.recv()
    #  K Q R B N P
    #  1 2 3 4 5 6   +0 black (lower case)
    #  9 A B C D E   +8 white (upper case)
    assert len(bs) == 64
    expected = (
        b""
        + b"\x03\x00\x05\x00\x04\x00\x02\x00"
        + b"\x01\x00\x04\x00\x05\x00\x03\x00"
        + b"\x06\x00\x06\x00\x06\x00\x06\x00"
        + b"\x06\x00\x06\x00\x06\x00\x06\x00"
        + b"\x0E\x00\x0E\x00\x0E\x00\x0E\x00"
        + b"\x0E\x00\x0E\x00\x0E\x00\x0E\x00"
        + b"\x0B\x00\x0D\x00\x0C\x00\x0A\x00"
        + b"\x09\x00\x0C\x00\x0D\x00\x0B\x00"
    )
    for i in range(64):
        assert bs[i] == expected[i], f"at cell {i} expected {expected[i]}"
    await Timer(2000, units="ns")
