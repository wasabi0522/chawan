# --- プロジェクト固有（各リポジトリで変更する箇所） ---
BASH_FILES := scripts/*.sh chawan.tmux

# --- 共通 ---
BATS_LIB_PATH := $(CURDIR)/tests/libs
export BATS_LIB_PATH

.PHONY: test lint fmt coverage setup

setup:
	@mkdir -p tests/libs
	@if [ ! -d tests/libs/bats-support ]; then \
		git clone --depth 1 https://github.com/bats-core/bats-support.git tests/libs/bats-support; \
	fi
	@if [ ! -d tests/libs/bats-assert ]; then \
		git clone --depth 1 https://github.com/bats-core/bats-assert.git tests/libs/bats-assert; \
	fi

test:
	bats tests/

lint:
	shellcheck $(BASH_FILES)
	shfmt -d -i 2 -ci $(BASH_FILES)

fmt:
	shfmt -w -i 2 -ci $(BASH_FILES)

coverage:
	@ruby run_coverage.rb --bash-path "$$(command -v bash)" --root . -- bats tests/ 2>&1 | tee /tmp/coverage-$$$$.log; \
	pct=$$(grep -oE '[0-9]+\.[0-9]+%' /tmp/coverage-$$$$.log | tail -1 | tr -d '%'); \
	rm -f /tmp/coverage-$$$$.log; \
	if [ -z "$$pct" ]; then echo "FAIL: Could not parse coverage percentage"; exit 1; fi; \
	echo "Coverage: $${pct}%"; \
	threshold=88; \
	if [ $$(echo "$$pct < $$threshold" | bc -l) -eq 1 ]; then \
	  echo "FAIL: Coverage $${pct}% is below $${threshold}% threshold"; \
	  exit 1; \
	else \
	  echo "OK: Coverage $${pct}% meets $${threshold}% threshold"; \
	fi
