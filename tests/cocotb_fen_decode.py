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
        board = chess.Board(fenstr)
        bs = fenstr.encode()
        await super().send(bs, **kwargs)
        return board


BINARY_PIECE = dict([(c,i) for i,c in enumerate(' kqrbnp  KQRBNP') if c != ' '])


def get_binary_board(board):
    #  K Q R B N P
    #  1 2 3 4 5 6   +0 black (lower case)
    #  9 A B C D E   +8 white (upper case)
    print(board)
    # {'K': 1, 'Q': 2, 'R': 3, 'B': 4, 'N': 5, 'P': 6, 'k': 9, 'q': 10, 'r': 11, 'b': 12, 'n': 13, 'p': 14}
    binary_board = bytearray(64)
    for rank in range(8):
        for file in range(8):
            sq = chess.square(rank, file)
            p = board.piece_at(sq)
            if p is not None:
                binary_board[rank + (7-file)*8] = BINARY_PIECE[p.symbol()]
    return bytes(binary_board)

def assert_board(bs, expected):
    print(bs)
    print(expected)
    assert len(bs) == 64
    for i in range(64):
        assert bs[i] == expected[i], f"at cell {i} expected {expected[i]}"


@cocotb.test()
async def test_fen_opening(dut):
    await cocotb.start(Clock(dut.clk, 1000).start())
    fd = FENDriver(dut.clk, dut.in_valid, dut.in_data, dut.in_sop, dut.in_eop)
    rcv = StreamReceiver(
        dut.clk, dut.o_pos_valid, dut.o_pos_data, dut.o_pos_sop, dut.o_pos_eop
    )
    await Timer(5, units="ns")
    await RisingEdge(dut.clk)  # wait for falling edge/"negedge"

    board = await fd.send(
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
    assert_board(
        bs,
        (
            b""
            + b"\x03\x05\x04\x02\x01\x04\x05\x03"
            + b"\x06\x06\x06\x06\x06\x06\x06\x06"
            + b"\x00\x00\x00\x00\x00\x00\x00\x00"
            + b"\x00\x00\x00\x00\x00\x00\x00\x00"
            + b"\x00\x00\x00\x00\x00\x00\x00\x00"
            + b"\x00\x00\x00\x00\x00\x00\x00\x00"
            + b"\x0E\x0E\x0E\x0E\x0E\x0E\x0E\x0E"
            + b"\x0B\x0D\x0C\x0A\x09\x0C\x0D\x0B"
        ),
    )
    assert_board(bs, get_binary_board(board))

    await Timer(2000, units="ns")

    board = await fd.send("8/5k2/8/8/5q2/3B4/8/4K3 w - - 0 29")
    bs = await rcv.recv()
    assert dut.o_hmcount.value == 0, "halfmove is not 0"
    assert dut.o_fmcount.value == 29, "fullmove is not 29"
    assert dut.o_wtp.value == 1, "expected white to play"
    assert dut.o_castle.value == 0, "castling rights not empty"
    assert dut.o_ep.value == 0, "no empassant"
    assert_board(bs, get_binary_board(board))

    await Timer(2000, units="ns")

    # test_longest_fenstring(dut):
    # 32 pieces, 64 squares, alternate
    # worst case fill of the internal FIFO
    board = await fd.send(
        "r1n1b1q1/k1b1n1r1/p1p1p1p1/p1p1p1p1/P1P1P1P1/P1P1P1P1/R1N1B1Q1/K1B1N1R1 w KQkq - 0 1",
        idler=IdleToggler(),
    )
    bs = await rcv.recv()
    assert_board(bs, get_binary_board(board))
    await Timer(2000, units="ns")
