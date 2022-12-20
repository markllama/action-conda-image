FROM continuumio/miniconda3:latest AS build
ENV CONDARC=/condarc.yaml

COPY build/* /

RUN conda env create --file /environment.yaml --name env && \
    conda install conda-pack && \
    conda-pack -j 4 -n env -o /tmp/env.tar && \
    mkdir /venv && \
    tar --directory /venv --extract --file /tmp/env.tar && \
    /venv/bin/conda-unpack

FROM debian:buster-slim

RUN apt-get update && \
    apt-get install -y \
        make \
        unzip \
        wget \
        curl \
        jq \
        git \
        && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -u 1001 -m runner

COPY --from=build --chown=1001:1001 /venv /venv

USER runner

ENV VIRTUAL_ENV=/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"
