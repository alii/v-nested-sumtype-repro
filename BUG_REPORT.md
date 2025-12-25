# Segfault with nested sum types when using -prod (-O3) on Linux x86_64

## Summary

A single 476-line V file causes a segmentation fault when compiled with `-prod` (GCC -O3) on Linux x86_64. The same code works correctly on macOS, and on Linux with `-O2` or debug builds.

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

| Environment | Build Command | Result |
|-------------|---------------|--------|
| Linux x86_64 | `v -prod repro.v` | **Segfault** |
| Linux x86_64 | `v repro.v` (debug) | Works |
| Linux x86_64 | `v -cc gcc -cflags "-O2" repro.v` | Works |
| macOS ARM64 | `v -prod repro.v` | Works |
| macOS ARM64 | `v repro.v` (debug) | Works |

## Root Cause Analysis

After extensive minimization (4000 lines → 476 lines), we identified the trigger:

### The Magic Number: 13 Expression Variants

The bug is extremely sensitive to sum type size:
- **12 Expression variants**: Works
- **13 Expression variants**: **Segfault**

This is the exact threshold - adding just one more variant to a working 12-variant sum type triggers the crash.

### Required Components

The bug requires ALL of these together:
1. **Two parallel sum type hierarchies** (AST and TypedAST with same structure)
2. **13+ Expression variants** in each hierarchy
3. **Recursive Statement type** (ExportDeclaration contains Statement)
4. **Match expressions** over these sum types
5. **Map writes** during match processing (`map[string]Type`)

Removing any one component causes the bug to disappear.

### Minimal Triggering Pattern

```v
// Two parallel sum types with 13 variants each
pub type AstExpression = A | B | C | D | E | F | G | H | I | J | K | L | M  // 13 variants
pub type TExpression = A | B | C | D | E | F | G | H | I | J | K | L | M    // 13 variants

// Recursive statement type
pub type AstStatement = AstExportDeclaration | ...
pub struct AstExportDeclaration { declaration AstStatement }  // recursive!

// Type environment with map
pub struct TypeEnv { mut: bindings map[string]Type }

// Match + map write = crash
fn (mut c TypeChecker) check_expr(expr AstExpression) TExpression {
    match expr {
        AstNumberLiteral { return TNumberLiteral{...} }
        // ... 12 more variants
    }
}

fn (mut c TypeChecker) check_statement(stmt AstStatement) TStatement {
    match stmt {
        AstVariableBinding {
            c.env.bindings[name] = t  // Map write during match triggers it
            // ...
        }
    }
}
```

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

| Stage | Lines | Files | Bug Triggers? |
|-------|-------|-------|---------------|
| Original codebase | ~4000 | 18+ | Yes |
| After removing unrelated features | ~2350 | 18 | Yes |
| After compacting utilities | ~1600 | 15 | Yes |
| After compacting all files | ~950 | 13 | Yes |
| **Single file** | **476** | **1** | **Yes** |

## File Structure (Single File)

The `repro.v` file contains:
- Span struct (source locations)
- Token types and Kind enum (65 variants)
- Diagnostic types
- AST types (13 Expression variants, 3 Statement variants)
- Typed AST types (mirrors AST structure)
- Scanner (~100 lines)
- Parser (~150 lines)
- Type checker (~80 lines)
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

This appears to be a GCC -O3 optimization bug triggered by the specific memory layout of:
- Large sum types (13+ variants)
- Recursive type definitions
- Map operations during pattern matching

The -O3 optimization likely miscompiles something in the generated C code for sum type dispatch or map access patterns.

## CI

The bug is continuously verified in CI: https://github.com/alii/v-nested-sumtype-repro/actions

- Linux job fails with exit code 139 (segfault) on `-prod` build
- macOS job passes all tests
- Linux with `-O2` passes

## Original Source

This was minimized from: https://github.com/alii/al (a programming language implementation)
