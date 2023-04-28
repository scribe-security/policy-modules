#!/bin/bash
 GOGC=1000 opa eval -b dist/bundle_*.tar.gz "data.example.vailation" --input test/input.json --profile --format=pretty