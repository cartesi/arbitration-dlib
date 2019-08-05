FROM ubuntu:18.04

MAINTAINER Carlo Fragni <carlo@cartesi.io>

ENV DEBIAN_FRONTEND=noninteractive

ENV BASE /opt/cartesi

# Install basic development tools
# ----------------------------------------------------
RUN \
    apt-get update && \
    apt-get install --no-install-recommends -y \
# TODO: Remove next line before open sourcing
        openssh-client \
        unzip build-essential autoconf automake libtool git \
        make curl g++ gcc libssl-dev pkg-config ca-certificates cmake && \
    mkdir -p $BASE

# TODO: Remove below section before open sourcing
# ----------------------------------------------------
# Add credentials on build, this is only a workaround when some of the repos are still private at the time
ARG SSH_PRIVATE_KEY="-----BEGIN OPENSSH PRIVATE KEY-----\n\
-----END OPENSSH PRIVATE KEY-----"

RUN mkdir -m 700 /root/.ssh
RUN echo "${SSH_PRIVATE_KEY}" > /root/.ssh/id_rsa
RUN chmod 400 /root/.ssh/id_rsa

# This is necessary to prevent the "git clone" operation from failing
# with an "unknown host key" error.
RUN touch -m 600 /root/.ssh/known_hosts; \
  ssh-keyscan github.com bitbucket.com > /root/.ssh/known_hosts

# ----------------------------------------------------
# TODO: Remove above section before open sourcing

# Install protobuf
# ----------------------------------------------------
WORKDIR $BASE
RUN \
    git clone --recurse-submodules --depth 1 https://github.com/protocolbuffers/protobuf.git

WORKDIR $BASE/protobuf
RUN \
    NPROC=$(nproc) && \
    ./autogen.sh && \
    ./configure && \
    make -j$NPROC && \
    make -j$NPROC check && \
    make -j$NPROC install && \
    ldconfig

WORKDIR $BASE
COPY ./compute/ $BASE/
RUN \
    rm -rf $BASE/protobuf

# Installing a rust stable
# ----------------------------------------------------
RUN \
    curl -f -L https://static.rust-lang.org/rustup.sh -O && \
    sh rustup.sh -y

# Loading cargo bin in path
ENV PATH="/root/.cargo/bin:$PATH"

# Compile dispatcher
WORKDIR $BASE
RUN \
# TODO: Remove next line before open sourcing
    eval `ssh-agent -s` && ssh-add -k /root/.ssh/id_rsa && \
    cargo build

###Cleaning up
#RUN \
#    rm -rf /var/lib/apt/lists/*

USER root
