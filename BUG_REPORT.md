# Bug Report for vlang/v

## Describe the bug

Program segfaults when compiled with `v -prod` on Linux x86_64. Works with debug build and on macOS.

## Reproduction Steps

```bash
git clone https://github.com/alii/v-nested-sumtype-repro
cd v-nested-sumtype-repro
v -prod -o repro repro.v
./repro
```

## Expected Behavior

Program prints "All tests passed!" and exits normally.

## Current Behavior

```
Parsed AST with 5 nodes
signal 11: segmentation fault
```

Exit code 139.

## V version

`V 0.4.12 24e9f68c6fad8a83c4da1dc233b883678de2261c`

## Environment details

```
OS                   linux, Ubuntu 24.04.3 LTS
Processor            64bit, AMD EPYC 7763 64-Core Processor
cc version           cc (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0
gcc version          gcc (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0
glibc version        ldd (Ubuntu GLIBC 2.39-0ubuntu8.6) 2.39
```

Works on macOS ARM64 with same V version.

## CI

https://github.com/alii/v-nested-sumtype-repro/actions
