.PHONY: test
.DEFAULT: test
test:
	/usr/bin/env perl report_tests.pl

old_test:
	@bash puppet_spec.sh
