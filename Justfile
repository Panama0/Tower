debug_out   := "out/debug/main"
release_out := "out/release/main"

default:
    @just --list

build-debug:
    odin build src -o:none -out:{{debug_out}} -debug

build-release:
    odin build src -o:speed -out:{{release_out}}

run-debug: build-debug
    {{debug_out}}

run-release: build-release
    {{release_out}}

test:
    odin test test

clean:
    rm -f {{debug_out}} {{release_out}}
