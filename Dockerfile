FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    strace \
    ltrace \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /analysis /output

WORKDIR /analysis
