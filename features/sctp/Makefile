.PHONY: test, ginkgo

ginkgo:
	go get github.com/onsi/ginkgo/ginkgo

e2etest: ginkgo
	cd test && ginkgo -r -- -junit /tmp/artifacts/unit_report.xml