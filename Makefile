.PHONY: test
.DEFAULT: test
test: 
	@bash puppet_spec.sh
