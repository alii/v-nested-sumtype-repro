module main

import src.types
import src.parser
import src.scanner

fn main() {
    source := '
x = 10
y = x + 1

fn add(a, b) { a + b }

fn greet(n) { n }

callback = fn(x) { x * 2 }

fn max(a, b) {
    if a > b { a } else { b }
}

fn classify(n) {
    if n < 0 { 0 - 1 } else if n == 0 { 0 } else { 1 }
}

fn example() {
    result = {
        a = 10
        b = 20
        a + b
    }
    result * 2
}

numbers = [1, 2, 3, 4, 5]
first = numbers[0]

sum = 1 + 2
diff = 5 - 3
prod = 4 * 2

a = 5
b = 10
eq = a == b
neq = a != b
lt = a < b
gt = a > b

add_result = add(5, 3)
max_result = max(10, 20)

export fn main_fn() {
    add_result + max_result
}
'

    mut s := scanner.new_scanner(source)
    mut p := parser.new_parser(mut s)
    result := p.parse_program()

    println('Parsed AST with ${result.ast.body.len} nodes')

    check_result := types.check(result.ast)
    if !check_result.success {
        println('Type check failed')
        return
    }
    println('Type checked: ${check_result.typed_ast.body.len} items')

    println('All tests passed!')
}
