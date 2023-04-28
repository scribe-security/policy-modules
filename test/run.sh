#!/bin/bash
bundle=`ls -t dist/ | head -n 1`
echo "Bundle: ${bundle}"
GOGC=1000 opa eval -b dist/${bundle} "data.example.Verify" --input test/input.json --profile --format=pretty