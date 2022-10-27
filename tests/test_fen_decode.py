
import cocotb
import chess
import logging

from cocotb.triggers import Timer, Event, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.binary import BinaryValue

class FenDriver:
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

@cocotb.test()
async def my_second_test(dut):
    """Try accessing the design."""

    await cocotb.start(Clock(dut.clk, 1000).start())

    fd = FenDriver(dut.clk, dut.valid, dut.data, dut.sop, dut.eop)

    await Timer(5, units="ns")  # wait a bit
    await RisingEdge(dut.clk)  # wait for falling edge/"negedge"

    await fd.send('8/5k2/8/8/5q2/3B4/8/4K3 w - - 0 29')

    await RisingEdge(dut.o_valid)
    print('edge up')
    await FallingEdge(dut.o_valid)
    print('edge down')

    assert dut.o_hmcount.value == 0, "halfmove is not 0"
    assert dut.o_fmcount.value == 29, "fullmove is not 29"
