.PHONY: test, ginkgo

deps:
	cd test && \
	go mod tidy && \
	go mod vendor

ginkgo:
	go get github.com/onsi/ginkgo/ginkgo

e2etest: ginkgo
	cd test && \
	GOFLAGS=-mod=vendor ginkgo -r -- -junit /tmp/artifacts/unit_report.xml