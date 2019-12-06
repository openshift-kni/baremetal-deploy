.PHONY: test, ginkgo

ginkgo:
	go get github.com/onsi/ginkgo/ginkgo

e2etest: ginkgo
	cd test && \
	go get &&  \
	ginkgo -r -- -junit /tmp/artifacts/unit_report.xml