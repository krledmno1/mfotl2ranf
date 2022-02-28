#!/bin/bash

cd "$(dirname "${0}")"
cd sinceuntil/

echo "Running experiments"

python3 run.py config_thesis.py
chmod +x run.sh
./run.sh

echo "Processing results"

python3 proc.py config_thesis.py

echo "Finished"
