# Segfault with `v -prod` on Linux x86_64

## Reproduction

```bash
git clone https://github.com/alii/v-nested-sumtype-repro
cd v-nested-sumtype-repro
v -prod -o repro repro.v && ./repro
```

## Results

| Platform | Command | Result |
|----------|---------|--------|
| Linux x86_64 | `v -prod` | Segfault |
| Linux x86_64 | `v` (debug) | Works |
| macOS ARM64 | `v -prod` | Works |

## CI

https://github.com/alii/v-nested-sumtype-repro/actions
