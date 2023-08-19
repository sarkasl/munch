#!/bin/sh

gleam build
python spec_test/spec_tests.py --spec spec.txt --program ./prog.sh $@ | colordiff