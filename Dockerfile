FROM ubuntu:22.10


RUN sed -i "s/http\:\/\/archive\.ubuntu\.com\//http\:\/\/ubuntu\.ethz\.ch\//g" /etc/apt/sources.list
RUN apt-get update
RUN apt-get upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y automake bc bison ca-certificates clang flex git gnuplot libgmp3-dev libssl-dev locales lld llvm make ninja-build m4 opam openjdk-8-jdk python3 python3-pip python3-setuptools scala texlive vim

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


# RUN wget https://github.com/Kitware/CMake/releases/download/v3.25.1/cmake-3.25.1.tar.gz; tar -zxvf cmake-3.25.1.tar.gz; cd cmake-3.25.1; ./bootstrap; make
# USER root
# RUN cd cmake-3.25.1; make install
# RUN pip3 install conan
# USER mfotlranf

# RUN git clone https://github.com/matthieugras/staticmon.git; 
# RUN cd staticmon;  
# RUN echo -e "./setup.sh << EOF\ng\n12\ny\nEOF" > bla.sh
# RUN bash bla.sh
# RUN ./configure.sh; cd ..
# RUN chmod a+x ./monpoly/monpoly


RUN cd ~ ; git clone https://github.com/matthieugras/monpoly.git monpoly-staticmon; cd monpoly-staticmon; eval `opam config env`; dune build --release
USER root
RUN ln -s /home/mfotlranf/monpoly-staticmon/_build/install/default/bin/monpoly /usr/bin/monpoly-staticmon
USER mfotlranf




# Startup
USER root
RUN echo 'export LD_LIBRARY_PATH=/usr/local/lib' >> /home/mfotlranf/.bashrc
RUN echo 'su - mfotlranf' >> /root/.bashrc
