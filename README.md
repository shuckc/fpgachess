Intro
---

A small chess engine that I hope to submit to one of the efabless / Google shuttle tapeout events.

Aim is to speak UCI over a UART, or some simpler protocol, then to generate scored moves back over the UART. It will be an exercise to learn both cototb for testing and yosys/openlanes for synthesis to gates.

* [efabless Project link](https://platform.efabless.com/projects/1454)

Tests
---
Test bench implemented with cocotb:

    $ python3 -m venv venv
    $ . venv/bin/activate
    $ pip install -r requirements.txt
    $ make

OR

    $ docker build .

To view waves

    $ gtkwave sim_build/test_fen_decode.vcd gtksaves/test_fen_decode.gtkw


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



