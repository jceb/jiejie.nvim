#!/usr/bin/env -S just --justfile
# Documentation: https://just.systems/man/en/

set shell := ['bash', '-euo', 'pipefail', '-c']

# Print this help
default:
    @just -l

# Format Justfile
format:
    @just --fmt --unstable

# Test application
test:
    nvim --headless -c "Lazy load plenary.nvim | PlenaryBustedDirectory tests/ {minimal_init = 'tests/jiejie_spec.lua'}"

# Development test application
dev-test tests='': test
    #!/usr/bin/env nu
    watch . --glob '*' {just test}

# Clean files
