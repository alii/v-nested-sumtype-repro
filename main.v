module main

import src.types
import src.ast
import src.span { Span }

fn s() Span {
    return span.point_span(0, 0)
}

fn main() {
    // Create AST manually instead of using parser
    body := [
        // struct User { id Int, name Int }
        ast.Node(ast.Statement(ast.StructDeclaration{
            identifier: ast.Identifier{ name: 'User', span: s() }
            fields: [
                ast.StructField{
                    identifier: ast.Identifier{ name: 'id', span: s() }
                    typ: ast.TypeIdentifier{ identifier: ast.Identifier{ name: 'Int', span: s() }, span: s() }
                },
                ast.StructField{
                    identifier: ast.Identifier{ name: 'name', span: s() }
                    typ: ast.TypeIdentifier{ identifier: ast.Identifier{ name: 'Int', span: s() }, span: s() }
                },
            ]
            span: s()
        })),

        // x = 10
        ast.Node(ast.Statement(ast.VariableBinding{
            identifier: ast.Identifier{ name: 'x', span: s() }
            init: ast.Expression(ast.NumberLiteral{ value: '10', span: s() })
            span: s()
        })),

        // fn add(a Int, b Int) Int { a + b }
        ast.Node(ast.Statement(ast.FunctionDeclaration{
            identifier: ast.Identifier{ name: 'add', span: s() }
            params: [
                ast.FunctionParameter{
                    identifier: ast.Identifier{ name: 'a', span: s() }
                    typ: ast.TypeIdentifier{ identifier: ast.Identifier{ name: 'Int', span: s() }, span: s() }
                },
                ast.FunctionParameter{
                    identifier: ast.Identifier{ name: 'b', span: s() }
                    typ: ast.TypeIdentifier{ identifier: ast.Identifier{ name: 'Int', span: s() }, span: s() }
                },
            ]
            return_type: ast.TypeIdentifier{ identifier: ast.Identifier{ name: 'Int', span: s() }, span: s() }
            body: ast.Expression(ast.BinaryExpression{
                left: ast.Expression(ast.Identifier{ name: 'a', span: s() })
                right: ast.Expression(ast.Identifier{ name: 'b', span: s() })
                op: ast.Operator{ kind: .punc_plus }
                span: s()
            })
            span: s()
        })),

        // result = add(5, 3)
        ast.Node(ast.Statement(ast.VariableBinding{
            identifier: ast.Identifier{ name: 'result', span: s() }
            init: ast.Expression(ast.FunctionCallExpression{
                identifier: ast.Identifier{ name: 'add', span: s() }
                arguments: [
                    ast.Expression(ast.NumberLiteral{ value: '5', span: s() }),
                    ast.Expression(ast.NumberLiteral{ value: '3', span: s() }),
                ]
                span: s()
            })
            span: s()
        })),

        // export fn main_fn() Int { result }
        ast.Node(ast.Statement(ast.ExportDeclaration{
            declaration: ast.Statement(ast.FunctionDeclaration{
                identifier: ast.Identifier{ name: 'main_fn', span: s() }
                params: []
                return_type: ast.TypeIdentifier{ identifier: ast.Identifier{ name: 'Int', span: s() }, span: s() }
                body: ast.Expression(ast.Identifier{ name: 'result', span: s() })
                span: s()
            })
            span: s()
        })),
    ]

    program := ast.BlockExpression{
        body: body
        span: s()
    }

    println('Created AST with ${program.body.len} nodes')

    // Type check - this is where the crash happens
    check_result := types.check(program)
    if !check_result.success {
        println('Type check failed')
        for d in check_result.diagnostics {
            println('  ${d.message}')
        }
        return
    }
    println('Type checked: ${check_result.typed_ast.body.len} items')

    println('All tests passed!')
}
