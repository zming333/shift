FROM golang:1.6 as builder

# BUILD shift-runner
RUN go get github.com/tools/godep
WORKDIR /go/src/github.com/square/shift/runner
COPY ./runner .
RUN godep get ./...
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o runner .

FROM ruby:2.2
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

WORKDIR /opt/code/shift

COPY ./ui/Gemfile ./ui/Gemfile.lock ./

# BUILD shift-ui
RUN bundle install

# INSTALL pt-osc
COPY ./ptosc-patch/0001-ptosc-square-changes.patch .
RUN cpanm YAML::Syck
RUN curl -sL -o pt-toolkit-2.2.15.deb https://www.percona.com/downloads/percona-toolkit/2.2.15/deb/percona-toolkit_2.2.15-2_all.deb \
    && dpkg -i pt-toolkit-2.2.15.deb \
    && rm pt-toolkit-2.2.15.deb \
    && patch /usr/bin/pt-online-schema-change 0001-ptosc-square-changes.patch

COPY --from=builder /go/src/github.com/square/shift/runner/runner .
COPY --from=builder /go/src/github.com/square/shift/runner/config ./config
COPY ./ui .

RUN mkdir -p /var/log/shift
ENV ENVIRONMENT=envvar \
    RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES=1 \
    SHIFT_REST_API=http://127.0.0.1:3000/api/v1/ \
    SHIFT_OSC_MYSQL_DEFAULTS_FILE=config/my.cnf \
    SHIFT_PT_OSC_PATH=/usr/bin/pt-online-schema-change \
    SHIFT_LOG_DIR=/var/log/shift

RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 3000
CMD ["/usr/bin/supervisord", "-n"]