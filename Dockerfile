FROM ubuntu:latest AS build
WORKDIR /app
RUN apt-get update && apt-get install -y git rlwrap bash curl gcc libreadline-dev gperf
RUN git clone https://github.com/steveicarus/iverilog.git
RUN apt-get update && apt-get install -y autoconf flex bison g++ make python3-pip
WORKDIR /app/iverilog/
RUN sh autoconf.sh && sh configure && make && make install
WORKDIR /app
COPY requirements.txt /app/
RUN pip install -r /app/requirements.txt
COPY Makefile /app/
COPY tests /app/tests
COPY hw /app/hw/
RUN make


