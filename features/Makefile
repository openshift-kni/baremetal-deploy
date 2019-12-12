
.PHONY: test, ginkgo

export FEATURES?=sctp

deps:
	go mod tidy && \
	go mod vendor

ginkgo:
	go get github.com/onsi/ginkgo/ginkgo

functests: ginkgo
	FOCUS=$$(echo $(FEATURES) | tr ' ' '|') && \
	echo "Focusing on $$FOCUS" && \
	GOFLAGS=-mod=vendor ginkgo functests --focus=$$FOCUS -- -junit /tmp/artifacts/unit_report.xml

unittests:
	# functests are marked with "// +build !unittests" and will be skipped
	GOFLAGS=-mod=vendor go test -v --tags unittests ./...

deploy:
	for f in $(FEATURES) ; \
    do \
	  echo "deploying $$f"; \
      ./$$f/deploy.sh; \
    done \
