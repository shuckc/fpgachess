import chess

# https://en.wikibooks.org/wiki/Chess/Notating_The_Game


def test_initial_moves():
    board = chess.Board()
    print(board.legal_moves)
    assert len(list(board.legal_moves)) == 20
    assert len(list(board.pseudo_legal_moves)) == 20
    # print(board.is_checkmate())


def test_kmoves_check():
    b = chess.Board("8/5k2/8/8/5q2/3B4/8/4K3 w - - 0 29")
    print(b)
    print(b.legal_moves)
    print(b.pseudo_legal_moves)

    # <LegalMoveGenerator at 0x7f832c861a20 (Bh7, Bg6+, Ba6, Bf5, Bb5, Be4, Bc4+, Be2, Bc2, Bf1, Bb1, Ke2, Kd1)>
    # <PseudoLegalMoveGenerator at 0x7f832c861a20 (Bh7, Bg6+, Ba6, Bf5, Bb5, Be4, Bc4+, Be2, Bc2, Bf1, Bb1, e1f2, Ke2, e1d2, e1f1, Kd1)>

    assert b.parse_san("Kd1") in b.legal_moves
    assert b.parse_san("Ke2") in b.legal_moves
    assert len(list(b.legal_moves)) == 13  # 2 for the king, 11 for B
    assert len(list(b.pseudo_legal_moves)) == 16  # 5 for the king, 11 for B

    # e1f2, e1d2, e1f1 leave K in check, not legal moves
    # b.parse_san parses only legal moves
    assert(chess.Move.from_uci("e1f2") in b.pseudo_legal_moves)
    assert(chess.Move.from_uci("e1f2") not in b.legal_moves)

def test_kmoves_promote():
    b = chess.Board("8/2P2P1k/8/8/8/8/8/4K3 w - - 0 29")
    print(b)
    print(b.legal_moves)
    print(b.pseudo_legal_moves)
    assert b.parse_san("Kd1") in b.legal_moves
    for m in "Kf2 Ke2 Kd2 Kf1 Kd1 f8=Q f8=R f8=B f8=N+ c8=Q c8=R c8=B c8=N".split():
        assert b.parse_san(m) in b.legal_moves
    assert len(list(b.legal_moves)) == 13  # 5 king, 2x4 pawn promotions
