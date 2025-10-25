FROM docker.io/library/debian:latest

# update apt sources and install ca-certificates
RUN apt-get update && apt-get install -y ca-certificates

# setup locales
RUN apt-get install -y locales && \
    apt-get clean
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# setup openssh server
RUN apt-get install -y openssh-server openssh-client && \
    apt-get clean
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
ADD --chmod=600 container/dev/authorized_keys /root/.ssh/authorized_keys
EXPOSE 22

# install network tools
RUN apt-get install -y ifupdown iproute2 net-tools iputils-arping iputils-clockdiff iputils-ping iputils-tracepath tcpdump nmap traceroute mtr netcat-openbsd whois wget curl aria2 && \
    apt-get clean

# install file, source management tools
RUN apt-get install -y coreutils findutils diffutils file git git-lfs gnupg unzip p7zip rsync && \
    apt-get clean

# install compilers and debuggers, build tools
RUN apt-get install -y build-essential llvm lldb gcc gdb clang-format strace valgrind make cmake ninja-build nodejs && \
    apt-get clean

# install monitoring tools
RUN apt-get install -y htop iftop && \
    apt-get clean

# install editors
RUN apt-get install -y vim nano binwalk && \
    apt-get clean

# install commonly used packages
RUN apt-get install -y man tmux stow jq tree python3-dev ffmpeg && \
    apt-get clean

# setup rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    /root/.cargo/bin/cargo --version

# setup uv toolchain
RUN curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --no-modify-path && \
    /root/.local/bin/uv --version

# apply stow configs
ADD stow/ /root/stow/
RUN cd /root/stow && \
    rm -rf ~/.bashrc* && \
    ./setup.sh

# set bash as default shell
RUN chsh -s /bin/bash root

# set working directory
WORKDIR /root

# entrypoint
CMD ["/usr/sbin/sshd", "-D"]
