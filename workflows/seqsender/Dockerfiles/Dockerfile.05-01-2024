FROM mambaorg/micromamba:1.5.5-jammy as app

LABEL base.image="mambaorg/micromamba:1.5.5"
LABEL dockerfile.version="1"
LABEL software="seqsender"
LABEL software.version="master"
LABEL description="Automated Pipeline to Generate FTP Files and Manage Submission of Sequence Data to Public Repositories"
LABEL website="https://github.com/CDCgov/seqsender"
LABEL license="https://github.com/CDCgov/seqsender/blob/master/LICENSE"
LABEL maintainer="Erik Wolfsohn"
LABEL maintainer.email="erik.wolfsohn@cchealth.org"

ARG SEQSENDER_SOFTWARE_VERSION="master"

USER root

RUN micromamba install -y -n base -c conda-forge python=3.6.15 requests unzip &&\
    micromamba clean --all --yes

ENV PATH="/opt/conda/bin:/opt/conda/envs/base/bin:${PATH}" \
    LC_ALL=C.UTF-8

RUN python -c "import requests; r = requests.get('https://codeload.github.com/erikwolfsohn/seqsender/zip/refs/heads/${SEQSENDER_SOFTWARE_VERSION}') ; open('seqsender-master.zip' , 'wb').write(r.content)" &&\
    unzip seqsender-master.zip
    
RUN sed -i 's/^name: seqsender$/name: base/' seqsender-master/env.yaml &&\  
    micromamba update -y --file seqsender-master/env.yaml &&\
    pip install --no-input nameparser==1.1.3

RUN mv seqsender-master /data

WORKDIR /data

CMD cd /data && python seqsender.py --help