#!/bin/bash

find . -name "*.zig" -exec sh -c "echo \"Testing {}\"; zig test {}" \;
