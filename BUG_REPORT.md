# Segfault with sum types + map writes under GCC -O3 on Linux x86_64

## Summary

A V program segfaults when compiled with `-prod` (GCC -O3) on Linux x86_64. Works on macOS, and on Linux with `-O2` or debug builds.

## Reproduction

```bash
git clone https://github.com/alii/v-nested-sumtype-repro
cd v-nested-sumtype-repro

# Crashes on Linux x86_64:
v -prod -o repro repro.v && ./repro

# Works:
v -o repro repro.v && ./repro
```

## Required Components

| Component                        | Required? |
| -------------------------------- | --------- |
| Parser with match over sum types | YES       |
| Type checker with map writes     | YES       |

Removing **either** makes the bug disappear.

## Workaround

Use `-O2` instead of `-O3` on Linux:

```bash
v -cc gcc -cflags "-O2" -o myapp .
```

## CI

https://github.com/alii/v-nested-sumtype-repro/actions
