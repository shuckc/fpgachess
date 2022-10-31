
import cocotb
import chess
import logging

from cocotb.triggers import Timer, Event, RisingEdge, FallingEdge, ReadOnly
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.binary import BinaryValue

class StreamDriver:
    """Basic 8-bit data with sop/eop markers and valid bits.
    FEN strings need a length-aware transport as the final field
    is an ascii digit length field, which could have more digits.
    Over a UART you could send a linebreak to indicate the end.
    """
    def __init__(self, clock, valid, data, sop, eop):
        self.log = logging.getLogger(f"cocotb.{data._path}")
        self.clock = clock
        self.valid = valid
        self.data = data
        self.sop = sop
        self.eop = eop
        self.queue = Queue()
        self.results = Queue()
        cocotb.fork(self._run())

    async def send(self, data: str):
        chess.Board(data)
        bs = data.encode()
        await self.queue.put(bs)
        await self.results.get()

    async def _run(self):
        try:
            self.valid.value = 0
            while True:
                bs = await self.queue.get()
                for i, b in enumerate(bs):
                    await RisingEdge(self.clock)
                    self.log.info(f"Write byte 0x{b:02x}")
                    self.valid.value = 1
                    self.data.value = b
                    self.sop.value = i == 0
                    self.eop.value = i == len(bs) - 1
                await RisingEdge(self.clock)
                self.valid.value = 0
                self.eop.value = BinaryValue('x')
                self.data.value = BinaryValue('x')
                self.sop.value = BinaryValue('x')
                await RisingEdge(self.clock)
                await self.results.put(True)
        except Exception:
            self.log.exception("ohno")

class StreamReceiver:
    """Basic 8-bit data with sop/eop markers and valid bits.
    FEN strings need a length-aware transport as the final field
    is an ascii digit length field, which could have more digits.
    Over a UART you could send a linebreak to indicate the end.
    """
    def __init__(self, clock, valid, data, sop, eop):
        self.log = logging.getLogger(f"cocotb.{data._path}")
        self.clock = clock
        self.valid = valid
        self.data = data
        self.sop = sop
        self.eop = eop
        self.results = Queue()
        self.burst = b""
        cocotb.fork(self._run())

    async def recv(self):
        return await self.results.get()

    async def _run(self):
        while True:
            await RisingEdge(self.clock)
            await ReadOnly()
            if self.valid.value:
                if self.burst == b"" and self.sop.value == False:
                    raise Exception("start of burst no sop")
                print(bytes(self.data.value))
                self.burst = self.burst + self.data.value.integer.to_bytes(1, 'little')
                b = self.data.value
                self.log.info(f"Read byte 0x{b} burst {self.burst}")
                if self.eop.value:
                    await self.results.put(self.burst)
                    self.burst = b""


@cocotb.test()
async def my_second_test(dut):
    """Try accessing the design."""

    await cocotb.start(Clock(dut.clk, 1000).start())

    fd = StreamDriver(dut.clk, dut.valid, dut.data, dut.sop, dut.eop)
    rcv = StreamReceiver(dut.clk, dut.pos_valid, dut.pos_data, dut.pos_sop, dut.pos_eop)
    await Timer(5, units="ns")
    await RisingEdge(dut.clk)  # wait for falling edge/"negedge"

    await fd.send('8/5k2/8/8/5q2/3B4/8/4K3 w - - 0 29')

    bs = await rcv.recv()

    assert dut.o_hmcount.value == 0, "halfmove is not 0"
    assert dut.o_fmcount.value == 29, "fullmove is not 29"
    assert dut.o_wtp == 1, "expected white to play"
    assert dut.o_castle == 0, "casteling rights not empty"
    assert dut.o_ep == 0,"no empassant"

    assert len(bs) == 64
    assert bs == (b'\0\0\0\0\0\0\0\0' +
                  b'\0\0\0\0\0\0\0\0' +
                  b'\0\0\0\0\0\0\0\0' +
                  b'\0\0\0\0\0\0\0\0' +
                  b'\0\0\0\0\0\0\0\0' +
                  b'\0\0\0\0\0\0\0\0' +
                  b'\0\0\0\0\0\0\0\0' +
                  b'\0\0\0\0\0\0\0\0')


