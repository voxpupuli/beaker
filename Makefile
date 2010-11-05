.PHONY: test
.DEFAULT: test

test: local_setup.sh
	DATE=$( date +"%s" )
	rm -f results/*.xml
	/usr/bin/env perl report_tests.pl
	tar cvfz results/archive/results-$DATE.tar.gz results/*.xml

old_test:
	@bash puppet_spec.sh
