FROM ncbi/pgap-utils:2023-10-03.build7061 as app

ARG PGAP_VER="2023-10-03.build7061"

LABEL base.image="ncbi/pgap-utils:2023-10-03.build7061"
LABEL dockerfile.version="1"
LABEL software="NCBI Prokaryotic Genome Annotation Pipeline"
LABEL software.version="2023-10-03.build7061"
LABEL description="The NCBI Prokaryotic Genome Annotation Pipeline is designed to annotate bacterial and archaeal genomes (chromosomes and plasmids)."
LABEL website="https://github.com/ncbi/pgap"
LABEL license="https://github.com/ncbi/pgap/blob/master/LICENSE.md"
LABEL maintainer="Erik Wolfsohn"
LABEL maintainer.email="erik.wolfsohn@cchealth.org"

RUN pip install --no-input cwltool
RUN pip install --no-input pyaml
RUN pip install --no-input --force-reinstall "urllib3==1.26.6"

RUN curl -L -o ${PGAP_VER}.tgz https://github.com/ncbi/pgap/archive/refs/tags/${PGAP_VER}.tar.gz && \
    tar -zxvf ${PGAP_VER}.tgz && \
    rm -v ${PGAP_VER}.tgz && \
    mv -v pgap-${PGAP_VER} /pgap

WORKDIR /data
