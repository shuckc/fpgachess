import chess

# https://en.wikibooks.org/wiki/Chess/Notating_The_Game
board = chess.Board()
print(board.legal_moves)

board.push_san("e4")
board.push_san("e5")
board.push_san("Qh5")
board.push_san("Nc6")
print(board)
print(board.legal_moves)
board.push_san("Bc4")
board.push_san("Nf6")
print(board)
print(board.legal_moves)
board.push_san("Qxf7")

print(board.is_checkmate())
print(board.legal_moves)
print(board)
print(repr(board))


def test_kmoves_check():
    # https://en.wikibooks.org/wiki/Chess/Notating_The_Game
    b = chess.Board("8/5k2/8/8/5q2/3B4/8/4K3 w - - 0 29")
    print(b)
    print(b.legal_moves)
    print(b.pseudo_legal_moves)

    assert b.parse_san("Kd1") in b.legal_moves
    assert b.parse_san("Ke2") in b.legal_moves
    assert len(list(b.legal_moves)) == 13  # 2 for the king, 11 for B

    print(b.pseudo_legal_moves)
    assert len(list(b.pseudo_legal_moves)) == 16  # 5 for the king, 11 for B
    # parse_san parsed only valid moves
    # assert b.parse_san('e1f2') in b.pseudo_legal_moves


def test_kmoves_promote():
    b = chess.Board("8/2P2P1k/8/8/8/8/8/4K3 w - - 0 29")
    print(b)
    print(b.legal_moves)
    print(b.pseudo_legal_moves)
    assert b.parse_san("Kd1") in b.legal_moves
    for m in "Kf2 Ke2 Kd2 Kf1 Kd1 f8=Q f8=R f8=B f8=N+ c8=Q c8=R c8=B c8=N".split():
        assert b.parse_san(m) in b.legal_moves
    assert len(list(b.legal_moves)) == 13  # 5 king, 2x4 pawn promotions
