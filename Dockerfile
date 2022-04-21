FROM ubuntu:20.04

RUN apt update
RUN apt -y install curl vim tree ack git
RUN apt -y install autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev

RUN useradd -ms /bin/bash -u 1000 user
USER 1000:1000

RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.9.0

RUN echo '. $HOME/.asdf/asdf.sh' >> /home/user/.bashrc
RUN echo '. $HOME/.asdf/completions/asdf.bash' >> /home/user/.bashrc
ENV BASH_ENV /home/user/.bashrc
ENV PATH /home/user/.asdf/bin:$PATH
RUN asdf plugin add ruby
RUN asdf install ruby latest
RUN asdf global ruby latest
WORKDIR /work
