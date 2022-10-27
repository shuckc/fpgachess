
Tests

    $ python3 -m venv venv
    $ pip install -r requirements.txt
    $ . venv/bin/activate
    $ make

OR

    $ docker build .

To view waves

    $ gtkwave sim_build/test_fen_decode.vcd gtksaves/test_fen_decode.gtkw
