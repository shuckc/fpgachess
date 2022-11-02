Intro
---

A small chess engine that I hope to submit to one of the efabless / Google shuttle tapeout events.

Aim is to speak UCI over a UART, or some simpler protocol, then to generate scored moves back over the UART. It will be an exercise to learn both cototb for testing and yosys/openlanes for synthesis to gates.

* [efabless Project link](https://platform.efabless.com/projects/1454)

Tests
---
Test bench implemented with cocotb:

    $ python3 -m venv venv
    $ pip install -r requirements.txt
    $ . venv/bin/activate
    $ make

OR

    $ docker build .

To view waves

    $ gtkwave sim_build/test_fen_decode.vcd gtksaves/test_fen_decode.gtkw
