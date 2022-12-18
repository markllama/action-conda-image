#FROM continuumio/miniconda3:latest AS build

#COPY 

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
RUN pip install yq
RUN useradd -u 1001 -m runner

#COPY --from=build --chown=1001:1001 /venv /venv

USER runner

#ENV VIRTUAL_ENV=/venv
#ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"
