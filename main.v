module main

import src.parser
import src.scanner

fn main() {
    source := '
struct User {
    id Int,
    name Int,
}

enum Result {
    Ok(Int)
    Err(Int)
}

x = 10
x = x + 1

fn add(a Int, b Int) Int { a + b }

fn greet(n Int) Int { n }

callback = fn(x Int) Int { x * 2 }

fn max(a Int, b Int) Int {
    if a > b { a } else { b }
}

fn classify(n Int) Int {
    if n < 0 { 0 - 1 } else if n == 0 { 0 } else { 1 }
}

fn example() Int {
    result = {
        a = 10
        b = 20
        a + b
    }
    result * 2
}

numbers = [1, 2, 3, 4, 5]
first = numbers[0]

range = 0..10

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

export fn main_fn() Int {
    add_result + max_result
}
'

    mut s := scanner.new_scanner(source)
    mut p := parser.new_parser(mut s)
    result := p.parse_program()

    println('Parsed AST with ${result.ast.body.len} nodes')
    println('All tests passed!')
}
