#!/bin/bash

all_test_files=`/bin/ls test_*.py | grep -v test_main.py`
python3.7 -m pytest $all_test_files