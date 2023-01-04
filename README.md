Intro
---

A small chess engine that I hope to submit to one of the efabless / Google shuttle tapeout events.

Aim is to speak UCI over a UART, or some simpler protocol, then to generate scored moves back over the UART. It will be an exercise to learn both cototb for testing and yosys/openlanes for synthesis to gates.

* [efabless Project link](https://platform.efabless.com/projects/1454)

Tests
---
Test bench implemented with `cocotb` and `cocotb-test`:

    $ sudo apt install python3.10-venv python3.10-dev iverilog
    $ python3 -m venv venv
    $ . venv/bin/activate
    $ pip install -r requirements.txt
    $ SIM=icarus pytest -o log_cli=True tests

OR

    $ docker build .

To build/view waves

    $ WAVES=1 pytest -o log_cli=True tests
    $ gtkwave sim_build/fen_decode.fst gtksaves/test_fen_decode.gtkw


Hardware
----
To build for different boards/simulators, use `fusesoc`, it is included in the `requirements.txt` above:

    $ pip install -r requirements.txt
    $ fusesoc library add fpgachess .
    $ fusesoc list cores

To see all supported targets:

    $ fusesoc core show shuckc:fpgachess:uci

To run a particular target:

    $ fusesoc run --target=lint shuckc:fpgachess:uci
    $ fusesoc run --target=orangecrab_r0.2 shuckc:fpgachess:uci



Test suites

---
* movegen / perft
  - https://www.chessprogramming.org/Perft_Results
  - http://www.talkchess.com/forum3/viewtopic.php?f=7&t=42463&sid=017c7f0619b356d590c8aa991d4b98c7
  - counts for a variety of positions https://www.stmintz.com/ccc/index.php?id=488817
  - https://github.com/elcabesa/vajolet/blob/master/tests/perft.txt
  - https://github.com/ChrisWhittington/Chess-EPDs

  - https://gist.github.com/peterellisjones/8c46c28141c162d1d8a0f0badbc9cff9

* scoring / best move
  - Hossa engine tests. 10 EPD files - new line separated FEN strings annotated with 'bm' (best move) comprising nearly 1,400 test positions.  http://www.jakob.at/steffen/hossa/

