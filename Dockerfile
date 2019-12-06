FROM rust:1.38 as builder

ENV BASE /opt/cartesi

RUN \
    apt-get update && \
    apt-get install --no-install-recommends -y cmake protobuf-compiler && \
    rm -rf /var/lib/apt/lists/*

WORKDIR $BASE/arbitration_test

# Compile cache arbitration test
COPY ./arbitration_test/Cargo_cache.toml ./Cargo.toml
RUN mkdir -p ./src && echo "fn main() { }" > ./src/main.rs
RUN cargo build -j $(nproc) --release

WORKDIR $BASE

COPY ./grpc-interfaces/ $BASE/grpc-interfaces
COPY ./dispatcher/ $BASE/dispatcher
COPY ./compute/ $BASE/compute
COPY ./emulator/ $BASE/emulator
COPY ./arbitration_test/ $BASE/arbitration_test

# Compile arbitration test
RUN cargo install -j $(nproc) --path ./arbitration_test


# Runtime image
FROM debian:buster-slim

ENV BASE /opt/cartesi

RUN \
    apt-get update && \
    apt-get install --no-install-recommends -y ca-certificates wget jq gawk && \
    rm -rf /var/lib/apt/lists/*

ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

WORKDIR $BASE

RUN mkdir -p $BASE/srv/dispatcher

# Copy the builder artifact from the build stage
COPY --from=builder /usr/local/cargo/bin/arbitration_test $BASE/bin/arbitration_test

# Copy dispatcher scripts
COPY ./dispatcher-entrypoint.sh $BASE/bin/dispatcher-entrypoint.sh

ENV ETHEREUM_HOST "ganache"
ENV ETHEREUM_PORT "8545"
ENV ETHEREUM_TIMEOUT "120s"

CMD dockerize \
    -wait file://$BASE/etc/keys/keys_done \
    -wait file://$BASE/share/blockchain/contracts/deploy_done \
    -wait file://$BASE/etc/dispatcher/config_done \
    -wait file:///root/host/test-files/files_done \
    -wait tcp://${ETHEREUM_HOST}:${ETHEREUM_PORT} \
    -wait tcp://machine-manager:50051 \
    -timeout ${ETHEREUM_TIMEOUT} \
    $BASE/bin/dispatcher-entrypoint.sh
