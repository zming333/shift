# compile runner
FROM golang:1.6 as builder

RUN go get github.com/tools/godep
COPY runner /go/src/github.com/square/shift/runner
RUN cd /go/src/github.com/square/shift/runner \
    && godep get ./... \
    && CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o runner .

# ui / runner runtime
FROM ruby:2.2

# install deps
RUN apt-get update && apt-get install -y \
    build-essential \
    cpanminus \
    libdbd-mysql-perl \
    libdbi-perl \
    libgmp3-dev \
    libio-socket-ssl-perl \
    libterm-readkey-perl \
    libyaml-perl \
    lsb-core \
    patch \
    perl \
    ruby-dev \
    supervisor

# install pt-toolkit
COPY ptosc-patch /opt/code/ptosc-patch
RUN cpanm YAML::Syck \
    && curl -sL -o pt-toolkit-2.2.15.deb https://www.percona.com/downloads/percona-toolkit/2.2.15/deb/percona-toolkit_2.2.15-2_all.deb \
    && dpkg -i pt-toolkit-2.2.15.deb && rm pt-toolkit-2.2.15.deb \
    && patch /usr/bin/pt-online-schema-change /opt/code/ptosc-patch/0001-ptosc-square-changes.patch

# copy runner executable
COPY --from=builder /go/src/github.com/square/shift/runner/runner /opt/code/runner/

# copy / install ui
COPY ui/Gemfile ui/Gemfile.lock /opt/code/ui/
RUN cd /opt/code/ui \
    && bundle install
COPY ui /opt/code/ui

# copy entrypoint script
COPY docker-entrypoint.sh /opt/code/

# runtime
WORKDIR /opt/code
EXPOSE 3000
ENTRYPOINT /opt/code/docker-entrypoint.sh

# TODO:
# patch ui/app/controllers/application_controller.rb to support cert-based account system
