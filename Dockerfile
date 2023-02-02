FROM ubuntu:22.10

RUN apt-get update
RUN apt-get upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y automake bc bison ca-certificates clang flex git gnuplot libgmp3-dev libssl-dev locales m4 opam openjdk-8-jdk python3 scala texlive vim

RUN adduser --disabled-password --gecos "" mfotlranf
RUN locale-gen en_US.UTF-8 &&\
    echo "export LANG=en_US.UTF-8 LANGUAGE=en_US.en LC_ALL=en_US.UTF-8" >> /home/mfotlranf/.bashrc

USER mfotlranf
ENV WDIR /home/mfotlranf
WORKDIR ${WDIR}

RUN opam init -y --disable-sandboxing
RUN opam install -y ocamlbuild ocamlfind ctypes dune dune-build-info menhir ppx_yojson_conv qcheck zarith
RUN opam switch create 4.05.0
RUN opam switch default

# MonPoly/VeriMon
RUN git clone https://bitbucket.org/jshs/monpoly.git
RUN eval `opam config env`; cd monpoly; dune build --release; dune install

# DejaVu
RUN git clone https://github.com/havelund/dejavu.git
RUN cp /home/mfotlranf/dejavu/out/dejavu /home/mfotlranf/dejavu/
RUN cp /home/mfotlranf/dejavu/out/artifacts/dejavu_jar/dejavu.jar /home/mfotlranf/dejavu/

# local files
ADD . ${WDIR}
USER root
RUN chmod 755 /home/mfotlranf
RUN chown -R mfotlranf:mfotlranf *
USER mfotlranf

# MonPoly-REG
RUN cd /home/mfotlranf/monpoly-reg-1.0/src/mona; ./configure; make
USER root
RUN cd /home/mfotlranf/monpoly-reg-1.0/src/mona; make install
USER mfotlranf
RUN opam switch 4.05.0; eval `opam config env`; cd monpoly-reg-1.0; make
RUN opam switch default

# MFOTL2RANF
RUN eval `opam config env`; make -C src

# Tools
RUN make -C sinceuntil
RUN make -C tools

# Startup
USER root
RUN echo 'export LD_LIBRARY_PATH=/usr/local/lib' >> /home/mfotlranf/.bashrc
RUN echo 'su - mfotlranf' >> /root/.bashrc
