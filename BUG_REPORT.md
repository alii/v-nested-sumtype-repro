# Segfault with nested sum types when using -prod (-O3) on Linux x86_64

## Summary

A single 472-line V file causes a segmentation fault when compiled with `-prod` (GCC -O3) on Linux x86_64. The same code works correctly on macOS, and on Linux with `-O2` or debug builds.

**Reproduction**: https://github.com/alii/v-nested-sumtype-repro

## Quick Reproduction

```bash
git clone https://github.com/alii/v-nested-sumtype-repro
cd v-nested-sumtype-repro

# This crashes on Linux x86_64:
v -prod -o repro repro.v
./repro
# signal 11: segmentation fault (exit code 139)

# This works:
v -cc gcc -cflags "-O2" -o repro repro.v
./repro
# All tests passed!
```

## What Works vs What Crashes

| Environment  | Build Command                     | Result       |
| ------------ | --------------------------------- | ------------ |
| Linux x86_64 | `v -prod repro.v`                 | **Segfault** |
| Linux x86_64 | `v repro.v` (debug)               | Works        |
| Linux x86_64 | `v -cc gcc -cflags "-O2" repro.v` | Works        |
| macOS ARM64  | `v -prod repro.v`                 | Works        |
| macOS ARM64  | `v repro.v` (debug)               | Works        |

## Root Cause Analysis

After extensive minimization (4000 lines → 472 lines) and systematic testing, we identified the **required** trigger:

### Verified Required Components

| Component | Required? | Notes |
|-----------|-----------|-------|
| Parser | ✅ YES | Without parser, just manual AST → works |
| Type checker | ✅ YES | Without type checker, just parse → works |
| Map writes in type checker | ✅ YES | Remove `c.env.define()` calls → works |
| @[heap] on Scanner | ❌ NO | Still crashes without it |
| Recursive statement type | ❌ NO | Still crashes without AstExportDeclaration |
| Two parallel sum types | Present in repro | Not independently tested |

### Key Finding

The bug requires **both**:
1. Full parser execution (with match expressions over sum types)
2. Type checker with map write operations (`map[string]Type`)

Removing **either** the type checker OR the map writes makes the bug disappear.

## The Crash

```
Parsed AST with 5 nodes
signal 11: segmentation fault
    | 0x55591aa6086b | ./repro(+0x1486b)
    | 0x55591aa67ab9 | ./repro(+0x1bab9)
    ...
Process completed with exit code 139.
```

The crash occurs in the type checker phase, after parsing completes successfully.

## Minimization Journey

| Stage                             | Lines   | Files | Bug Triggers? |
| --------------------------------- | ------- | ----- | ------------- |
| Original codebase                 | ~4000   | 18+   | Yes           |
| After removing unrelated features | ~2350   | 18    | Yes           |
| After compacting utilities        | ~1600   | 15    | Yes           |
| After compacting all files        | ~950    | 13    | Yes           |
| **Single file**                   | **472** | **1** | **Yes**       |

## File Structure (Single File)

The `repro.v` file contains:
- Span struct (source locations)
- Token types and Kind enum (65 variants)
- Diagnostic types
- AST types (Expression and Statement sum types)
- Typed AST types (mirrors AST structure)
- Scanner (~100 lines)
- Parser (~150 lines)
- Type checker (~80 lines) - **contains the map writes that trigger the bug**
- Main function

## V Version

Tested with:
- V weekly.2025.49-103-g1cdb0f57
- Latest V from GitHub releases

## Workaround

Use `-O2` instead of `-O3` on Linux:

```bash
v -cc gcc -cflags "-O2" -o myapp .
```

Or in CI:
```yaml
- name: Build
  run: |
    if [ "${{ runner.os }}" = "Linux" ]; then
      v -cc gcc -cflags "-O2" -o app .
    else
      v -prod -o app .
    fi
```

## Hypothesis

This appears to be a GCC -O3 optimization bug triggered by the combination of:
- Complex match expressions in parser producing sum type values
- Map write operations in the type checker consuming those values

The -O3 optimization likely miscompiles something related to sum type dispatch combined with map access patterns.

## CI

The bug is continuously verified in CI: https://github.com/alii/v-nested-sumtype-repro/actions

- Linux job fails with exit code 139 (segfault) on `-prod` build
- macOS job passes all tests
- Linux with `-O2` passes

## Original Source

This was minimized from: https://github.com/alii/al (a programming language implementation)
