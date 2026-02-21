.PHONY: test lint fmt coverage

test:
	bats tests/

lint:
	shellcheck scripts/*.sh chawan.tmux
	shfmt -d -i 2 -ci scripts/*.sh chawan.tmux

fmt:
	shfmt -w -i 2 -ci scripts/*.sh chawan.tmux

coverage:
	ruby run_coverage.rb --bash-path "$$(command -v bash)" --root . -- bats tests/
