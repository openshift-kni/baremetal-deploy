
export FEATURES?=mcp performance sctp

.PHONY: deps-update
deps-update:
	GO111MODULE=on go mod tidy && \
	GO111MODULE=on go mod vendor

ginkgo:
	go get github.com/onsi/ginkgo/ginkgo

.PHONY: functests
functests: ginkgo
	FOCUS=$$(echo $(FEATURES) | tr ' ' '|') && \
	echo "Focusing on $$FOCUS" && \
	GOFLAGS=-mod=vendor ginkgo functests --focus=$$FOCUS -- -junit /tmp/artifacts/unit_report.xml

.PHONY: unittests
unittests:
	# functests are marked with "// +build !unittests" and will be skipped
	GOFLAGS=-mod=vendor go test -v --tags unittests ./...

.PHONY: deploy
deploy: generate
	for f in $(FEATURES); do \
		if [ -f ./$$f/deploy.sh ]; then \
			echo "[INFO]: deploying $$f"; \
			./$$f/deploy.sh; \
		else \
			echo "[WARN]: no deploy.sh script found for the feature $$f"; \
		fi; \
	done

.PHONY: generate
generate:
	for f in $(FEATURES); do \
		if [ -f ./$$f/generate.sh ]; then \
			echo "[INFO]: generating manifests $$f"; \
			./$$f/generate.sh; \
		else \
			echo "[WARN]: no generate.sh script found for the feature $$f"; \
		fi; \
	done
