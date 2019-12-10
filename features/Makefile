
.PHONY: test, ginkgo

deps:
	go mod tidy && \
	go mod vendor

ginkgo:
	go get github.com/onsi/ginkgo/ginkgo

functests: ginkgo
	GOFLAGS=-mod=vendor ginkgo functests -- -junit /tmp/artifacts/unit_report.xml

unittests:
	GO_PACKAGES=$$(go list ./...| grep -v /functests); \
	if [ -n "$$GO_PACKAGES" ]; then go test $$GO_PACKAGES; fi; 

