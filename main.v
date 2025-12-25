module main

import src.types
import src.parser
import src.scanner

fn main() {
    source := '
x = 1
y = 2
z = x + y
fn add(a Int, b Int) Int { a + b }
result = add(1, 2)
'

    mut s := scanner.new_scanner(source)
    mut p := parser.new_parser(mut s)
    result := p.parse_program()

    println('Parsed AST with ${result.ast.body.len} nodes')

    // Type check - this is where the crash happens
    check_result := types.check(result.ast)
    if !check_result.success {
        println('Type check failed')
        return
    }
    println('Type checked: ${check_result.typed_ast.body.len} items')

    println('All tests passed!')
}
