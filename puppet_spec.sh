#!/bin/bash
for SPEC in spec/**/*_spec.sh ; do
	bash $SPEC 
done 
