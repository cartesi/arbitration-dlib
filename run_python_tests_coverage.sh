#!/bin/bash
cd ./test
# activate virtualenv if file found
file_active=./bin/activate
if [ -f $file_active ]; then
    source $file_active
fi
all_test_files=`/bin/ls ./test_*.py | grep -v test_main.py`
python3.7 -m pytest $all_test_files --port 8555