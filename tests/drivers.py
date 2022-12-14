import cocotb
import logging

from cocotb.triggers import Timer, Event, RisingEdge, FallingEdge, ReadOnly
from cocotb.queue import Queue
from cocotb.binary import BinaryValue
import itertools


def IdleToggler():
    while True:
        yield True
        yield False


class StreamDriver:
    """Basic 8-bit data with sop/eop markers and valid bits."""

    def __init__(self, clock, valid, data, sop, eop):
        self.log = logging.getLogger(f"cocotb.{data._path}")
        self.clock = clock
        self.valid = valid
        self.data = data
        self.data_width = len(data)
        self.sop = sop
        self.eop = eop
        self.queue = Queue()
        self.results = Queue()
        cocotb.start_soon(self._run())

    async def send(self, bs: bytes, idler=itertools.repeat(True)):
        await self.queue.put((bs, idler))
        await self.results.get()

    async def _run(self):
        try:
            self.valid.value = 0
            while True:
                bs, idler = await self.queue.get()
                for i, b in enumerate(bs):
                    await RisingEdge(self.clock)
                    while not next(idler):
                        self.valid.value = 0
                        self.eop.value = BinaryValue("x")
                        self.data.value = BinaryValue("x" * self.data_width)
                        self.sop.value = BinaryValue("x")
                        await RisingEdge(self.clock)
                    # self.log.info(f"Write byte 0x{b:02x}")
                    self.valid.value = 1
                    self.data.value = b
                    self.sop.value = i == 0
                    self.eop.value = i == len(bs) - 1

                await RisingEdge(self.clock)
                self.valid.value = 0
                self.eop.value = BinaryValue("x")
                self.data.value = BinaryValue("x" * self.data_width)
                self.sop.value = BinaryValue("x")
                await RisingEdge(self.clock)
                await self.results.put(True)
        except Exception:
            self.log.exception("ohno")


class StrobeDriver:
    def __init__(self, clock, valid):
        self.log = logging.getLogger(f"cocotb.{valid._path}")
        self.clock = clock
        self.valid = valid
        self.queue = Queue()
        self.results = Queue()
        cocotb.start_soon(self._run())

    async def strobe(self, idler=itertools.repeat(True)):
        await self.queue.put((b'1', idler))
        await self.results.get()

    async def _run(self):
        try:
            self.valid.value = 0
            while True:
                bs, idler = await self.queue.get()
                for i, b in enumerate(bs):
                    await RisingEdge(self.clock)
                    while not next(idler):
                        self.valid.value = 0
                        await RisingEdge(self.clock)
                    self.valid.value = 1

                await RisingEdge(self.clock)
                self.valid.value = 0
                await self.results.put(True)
        except Exception:
            self.log.exception("ohno")

class StreamReceiver:
    def __init__(self, clock, valid, data, sop, eop):
        self.log = logging.getLogger(f"cocotb.{data._path}")
        self.clock = clock
        self.valid = valid
        self.data = data
        self.sop = sop
        self.eop = eop
        self.results = Queue()
        self.timeout_queue = Queue()
        self.bursts = []
        cocotb.start_soon(self._run())

    async def recv(self, timeout=2000):
        await self.timeout_queue.put(timeout)
        return await self.results.get()

    def extract(self, value):
        return value.integer.to_bytes(1, "little")

    def compact(self, burst):
        return b"".join(burst)

    async def _run(self):
        while True:
            burst = []
            timeout = await self.timeout_queue.get()
            cycle = 0
            while True:
                await RisingEdge(self.clock)
                await ReadOnly()
                cycle = cycle + 1
                if self.valid.value:
                    self.log.info(f"Read byte valid={self.valid.value} data={self.data.value} sop={self.sop.value} eop={self.eop.value}")

                    if not burst and self.sop.value == False:
                        raise Exception("start of burst no sop")
                    burst.append(self.extract(self.data.value))
                    if self.eop.value:
                        await self.results.put(self.compact(burst))
                        break
                if cycle > timeout:
                    value = self.compact(burst)
                    e = Exception(
                        f"StreamReciever hit timeout after {timeout} cycles. Pending data: {value}"
                    )
                    e.value = value
                    raise e
