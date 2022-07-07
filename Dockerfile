FROM --platform=linux/amd64 ubuntu:20.04 as builder

RUN DEBIAN_FRONTEND=noninteractive apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y gcc g++ make

ADD . /expandpass
WORKDIR /expandpass
RUN make

#FROM ubuntu:20.04 as package

#COPY --from=builder /jefferson/jefferson.bin /jefferson
#COPY --from=builder /jefferson/example_file_system.jffs2 /example_file_system.jffs2

# Technically build and 'package'
# build step with required supporting packages
# package step new docker with binaryldd
# go make gcc cmake clang curl
