import cocotb
import logging

from cocotb.triggers import Timer, Event, RisingEdge, FallingEdge, ReadOnly
from cocotb.queue import Queue
from cocotb.binary import BinaryValue

class StreamDriver:
    """Basic 8-bit data with sop/eop markers and valid bits.
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

    async def send(self, bs:bytes):
        await self.queue.put(bs)
        await self.results.get()

    async def _run(self):
        try:
            self.valid.value = 0
            while True:
                bs = await self.queue.get()
                for i, b in enumerate(bs):
                    await RisingEdge(self.clock)
                    #self.log.info(f"Write byte 0x{b:02x}")
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
    def __init__(self, clock, valid, data, sop, eop):
        self.log = logging.getLogger(f"cocotb.{data._path}")
        self.clock = clock
        self.valid = valid
        self.data = data
        self.sop = sop
        self.eop = eop
        self.results = Queue()
        self.bursts = []
        cocotb.fork(self._run())

    async def recv(self):
        return await self.results.get()

    async def _run(self):
        while True:
            await RisingEdge(self.clock)
            await ReadOnly()
            if self.valid.value:
                if not self.bursts and self.sop.value == False:
                    raise Exception("start of burst no sop")
                self.bursts.append(self.data.value.integer.to_bytes(1, 'little'))
                b = self.data.value
                # self.log.info(f"Read byte 0x{b}")
                if self.eop.value:
                    await self.results.put(b''.join(self.bursts))
                    self.bursts = []



