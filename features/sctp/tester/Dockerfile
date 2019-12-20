
FROM golang:1.13 AS builder
WORKDIR /gotest
COPY . .
RUN go mod init github.com/openshift-kni/baremetal-prep/sctptester
RUN go get
RUN go build -o sctptest

FROM centos:7
COPY --from=builder /gotest/sctptest /usr/bin/sctptest
CMD ["/usr/bin/sctptest"]
