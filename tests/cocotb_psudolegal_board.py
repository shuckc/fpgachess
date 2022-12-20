import cocotb
import chess
import logging

from cocotb.triggers import Timer, Event, RisingEdge, FallingEdge, ReadOnly
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.binary import BinaryValue

from drivers import StreamDriver, StreamReceiver, IdleToggler, StrobeDriver
from cocotb_fen_decode import get_binary_board, BINARY_PIECE, TEXT_PIECE

def encode_casteling_bits(board):
    v = 0 | board.has_kingside_castling_rights(chess.WHITE) << 3
    v = v | board.has_queenside_castling_rights(chess.WHITE) << 2
    v = v | board.has_kingside_castling_rights(chess.BLACK) << 1
    v = v | board.has_queenside_castling_rights(chess.BLACK) << 0
    return v

class BinaryBoardDriver(StreamDriver):
    def __init__(self, clock, valid, data, sop, eop, hmcount, fmcount, wtp, castle, ep):
        self.hmcount = hmcount
        self.fmcount = fmcount
        self.wtp = wtp
        self.castle = castle
        self.ep = ep
        super().__init__(clock, valid, data, sop, eop)

    def _encode_ep_bits(self, board):
        if board.ep_square is None:
            return 0
        return 1 + chess.square_file(board.ep_square)

    """
    FEN strings need a length-aware transport as the final field
    is an ascii digit length field, which could have more digits.
    Over a UART you could send a linebreak to indicate the end.
    """
    async def send(self, fenstr: str, **kwargs):
        # validates or fires exception
        board = chess.Board(fenstr)
        binary_pieces = get_binary_board(board)
        assert(len(binary_pieces) == 64)

        # set immediately, keep valid for all 64 transfer cycles
        if self.hmcount is not None:
            self.hmcount.value = board.halfmove_clock
        if self.fmcount is not None:
            self.fmcount.value = board.fullmove_clock
        self.wtp.value = board.turn == chess.WHITE
        self.castle.value = encode_casteling_bits(board)
        self.ep.value = self._encode_ep_bits(board)
        await super().send(binary_pieces, **kwargs)
        return board

#  K Q R B N P
#  1 2 3 4 5 6   +0 black (lower case)
#  k q r b n p
#  9 A B C D E   +8 white (upper case)
class StreamValueReceiver(StreamReceiver):
    def extract(self, value):
        value.big_endian = False
        return value
    def compact(self, results):
        return results


def decodeItem(value):
    v = value.out_data.value.integer
    file = "abcdefgh"[v & 7]
    rank = "12345678"[(v >> 3) & 7]
    # no player bit in this encoding, as that is used for bank select, returns black piece chars
    p = TEXT_PIECE[(v >> 6) & 7]
    if (v >> 9) & 1 == 0:
        return None
    return (p, f"{file}{rank}")

def encode_pseudo_legal_moves(board):
    # prom_encoded = {None: 0, chess.PieceType.QUEEN: 2, chess.PieceType.ROOK: 3, chess.PieceType.BISHOP: 4, chess.PieceType.KNIGHT: 5}
    moves = set()
    for m in board.pseudo_legal_moves:
        uci = m.uci()
        p = board.piece_at(m.from_square)
        if p is not None and p.piece_type is not chess.PAWN:
            uci = f"{chess.PIECE_SYMBOLS[p.piece_type]}{uci}"
        # p = prom_encoded[m.promotion]
        moves.add(uci)
    return moves

def encode_binary_moves(binary_moves):
    # adding the piece to the usual uci code
    # format is "Qa3a4" or "a3a4" for a non-promoting pawn move.
    # add "x[PQNB]" etc for taking
    # castelling specified as the king move
    moves = set()
    files = "abcdefgh"
    ranks = "12345678"
    for m in binary_moves:
        # bit order: rank,file
        p = TEXT_PIECE[m[17:15].integer]
        uci = f"{files[m[14:12].integer]}{ranks[m[11:9].integer]}{files[m[5:3].integer]}{ranks[m[2:0].integer]}"
        if p != "p":
            uci = f"{p}{uci}"
        moves.add(uci)
    return moves

def assert_moves_equal(binary_stream, board):
    bin_moves = encode_binary_moves(binary_stream)
    board_moves = encode_pseudo_legal_moves(board)
    missing = board_moves - bin_moves
    extra = bin_moves - board_moves
    if missing or extra:
        print(bin_moves)
        print(board_moves)
        raise Exception(f"mismatch moves: missing {missing}, extra {extra}")


@cocotb.test()
async def test_psudo_legal_moves(dut):

    await cocotb.start(Clock(dut.clk, 1000).start())
    fd = BinaryBoardDriver(dut.clk, dut.in_pos_valid, dut.in_pos_data, dut.in_pos_sop, dut.in_pos_eop, None, None, dut.in_wtp, dut.in_castle, dut.in_ep)
    rcv = StreamValueReceiver(
        dut.clk, dut.o_uci_valid, dut.o_uci_data, dut.o_uci_sop, dut.o_uci_eop
    )
    start_strobe = StrobeDriver(dut.clk, dut.start)
    await Timer(5, units="ns")
    await RisingEdge(dut.clk)  # wait for falling edge/"negedge"

    board = await fd.send(
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    )
    # assert pos within board squares to ensure fen serial load ordering correct
    assert dut.rank[0].file[0].movegen_square.pos.value == BINARY_PIECE['R'] # a1 = R
    assert dut.rank[0].file[4].movegen_square.pos.value == BINARY_PIECE['K'] # e1 = K
    assert dut.rank[7].file[4].movegen_square.pos.value == BINARY_PIECE['k'] # e8 = k
    assert dut.rank[7].file[0].movegen_square.pos.value == BINARY_PIECE['r'] # a8 = r

    # assert black move stack (last piece is top)
    assert decodeItem(dut.item[0].movegen_piece_black) == ('p', 'h7')
    assert decodeItem(dut.item[1].movegen_piece_black) == ('p', 'g7')
    assert decodeItem(dut.item[2].movegen_piece_black) == ('p', 'f7')
    assert decodeItem(dut.item[3].movegen_piece_black) == ('p', 'e7')
    assert decodeItem(dut.item[4].movegen_piece_black) == ('p', 'd7')
    assert decodeItem(dut.item[5].movegen_piece_black) == ('p', 'c7')
    assert decodeItem(dut.item[6].movegen_piece_black) == ('p', 'b7')
    assert decodeItem(dut.item[7].movegen_piece_black) == ('p', 'a7')
    assert decodeItem(dut.item[ 8].movegen_piece_black) == ('r', 'h8')
    assert decodeItem(dut.item[ 9].movegen_piece_black) == ('n', 'g8')
    assert decodeItem(dut.item[10].movegen_piece_black) == ('b', 'f8')
    assert decodeItem(dut.item[11].movegen_piece_black) == ('k', 'e8')
    assert decodeItem(dut.item[12].movegen_piece_black) == ('q', 'd8')
    assert decodeItem(dut.item[13].movegen_piece_black) == ('b', 'c8')
    assert decodeItem(dut.item[14].movegen_piece_black) == ('n', 'b8')
    assert decodeItem(dut.item[15].movegen_piece_black) == ('r', 'a8')

    # white move stack (last piece is top)
    assert decodeItem(dut.item[0].movegen_piece_white) == ('r', 'h1')
    assert decodeItem(dut.item[1].movegen_piece_white) == ('n', 'g1')
    assert decodeItem(dut.item[2].movegen_piece_white) == ('b', 'f1')
    assert decodeItem(dut.item[3].movegen_piece_white) == ('k', 'e1')
    assert decodeItem(dut.item[4].movegen_piece_white) == ('q', 'd1')
    assert decodeItem(dut.item[15].movegen_piece_white) == ('p', 'a2')

    await start_strobe.strobe()
    bs = await rcv.recv()

    await Timer(5, units="ns")
    assert_moves_equal(bs, board)

    # flip the side to play and check black moves
    board = await fd.send(
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1"
    )

    # assert black move stack (last piece is top)
    assert decodeItem(dut.item[0].movegen_piece_black) == ('p', 'h7')
    assert decodeItem(dut.item[1].movegen_piece_black) == ('p', 'g7')
    assert decodeItem(dut.item[2].movegen_piece_black) == ('p', 'f7')
    assert decodeItem(dut.item[3].movegen_piece_black) == ('p', 'e7')
    assert decodeItem(dut.item[4].movegen_piece_black) == ('p', 'd7')
    assert decodeItem(dut.item[5].movegen_piece_black) == ('p', 'c7')
    assert decodeItem(dut.item[6].movegen_piece_black) == ('p', 'b7')
    assert decodeItem(dut.item[7].movegen_piece_black) == ('p', 'a7')
    assert decodeItem(dut.item[ 8].movegen_piece_black) == ('r', 'h8')
    assert decodeItem(dut.item[ 9].movegen_piece_black) == ('n', 'g8')
    assert decodeItem(dut.item[10].movegen_piece_black) == ('b', 'f8')
    assert decodeItem(dut.item[11].movegen_piece_black) == ('k', 'e8')
    assert decodeItem(dut.item[12].movegen_piece_black) == ('q', 'd8')
    assert decodeItem(dut.item[13].movegen_piece_black) == ('b', 'c8')
    assert decodeItem(dut.item[14].movegen_piece_black) == ('n', 'b8')
    assert decodeItem(dut.item[15].movegen_piece_black) == ('r', 'a8')

    # white move stack (last piece is top)
    assert decodeItem(dut.item[0].movegen_piece_white) == ('r', 'h1')
    assert decodeItem(dut.item[1].movegen_piece_white) == ('n', 'g1')
    assert decodeItem(dut.item[2].movegen_piece_white) == ('b', 'f1')
    assert decodeItem(dut.item[3].movegen_piece_white) == ('k', 'e1')
    assert decodeItem(dut.item[4].movegen_piece_white) == ('q', 'd1')
    assert decodeItem(dut.item[15].movegen_piece_white) == ('p', 'a2')

    await start_strobe.strobe()
    bs = await rcv.recv()
    await Timer(5, units="ns")

    assert_moves_equal(bs, board)

async def test_fen_moves(start_strobe, fd, rcv, fenstr):
    board = await fd.send(fenstr)
    await start_strobe.strobe()
    bs = await rcv.recv()
    await Timer(5, units="ns")
    assert_moves_equal(bs, board)


@cocotb.test()
async def test_kiwipete_moves(dut):
    # Kiwipete by Peter McKenzie, a well-known test
    # position for takes/check taken from
    # https://www.chessprogramming.org/Perft_Results

    await cocotb.start(Clock(dut.clk, 1000).start())
    fd = BinaryBoardDriver(dut.clk, dut.in_pos_valid, dut.in_pos_data, dut.in_pos_sop, dut.in_pos_eop, None, None, dut.in_wtp, dut.in_castle, dut.in_ep)
    rcv = StreamValueReceiver(
        dut.clk, dut.o_uci_valid, dut.o_uci_data, dut.o_uci_sop, dut.o_uci_eop
    )
    start_strobe = StrobeDriver(dut.clk, dut.start)
    await Timer(5, units="ns")
    await RisingEdge(dut.clk)

    # kiwipete
    await test_fen_moves(start_strobe, fd, rcv, "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
    await test_fen_moves(start_strobe, fd, rcv, "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R b KQkq - 0 1")

    # tests from https://gist.github.com/peterellisjones/8c46c28141c162d1d8a0f0badbc9cff9

    await test_fen_moves(start_strobe, fd, rcv, "r6r/1b2k1bq/8/8/7B/8/8/R3K2R b KQ - 3 2")
    # ep test - c4d3 is ep capture
    await test_fen_moves(start_strobe, fd, rcv, "8/8/8/2k5/2pP4/8/B7/4K3 b - d3 0 3")
    await test_fen_moves(start_strobe, fd, rcv, "r1bqkbnr/pppppppp/n7/8/8/P7/1PPPPPPP/RNBQKBNR w KQkq - 2 2")
    # cannot castle when in check
    await test_fen_moves(start_strobe, fd, rcv, "r3k2r/p1pp1pb1/bn2Qnp1/2qPN3/1p2P3/2N5/PPPBBPPP/R3K2R b KQkq - 3 2")
    await test_fen_moves(start_strobe, fd, rcv, "2kr3r/p1ppqpb1/bn2Qnp1/3PN3/1p2P3/2N5/PPPBBPPP/R3K2R b KQ - 3 2")
    await test_fen_moves(start_strobe, fd, rcv, "rnb2k1r/pp1Pbppp/2p5/q7/2B5/8/PPPQNnPP/RNB1K2R w KQ - 3 9")
