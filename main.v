module main

import src.typed_ast
import src.bytecode
import src.types
import src.flags
import src.span { Span }
import src.type_def

fn main() {
    // Build AST nodes like the real compiler does
    num := typed_ast.Expression(typed_ast.NumberLiteral{ value: '42', span: span.point_span(0, 0) })
    str := typed_ast.Expression(typed_ast.StringLiteral{ value: 'hello', span: span.point_span(0, 0) })
    ident := typed_ast.Expression(typed_ast.Identifier{ name: 'x', span: span.point_span(0, 0) })

    var_bind := typed_ast.Statement(typed_ast.VariableBinding{
        identifier: typed_ast.Identifier{ name: 'x', span: span.point_span(0, 0) }
        init:       num
        span:       span.point_span(0, 0)
    })

    block := typed_ast.Expression(typed_ast.BlockExpression{
        body: [
            typed_ast.BlockItem{ is_statement: true, statement: var_bind },
            typed_ast.BlockItem{ is_statement: false, expression: num },
            typed_ast.BlockItem{ is_statement: false, expression: str },
        ]
        span: span.point_span(0, 0)
    })

    fn_decl := typed_ast.Statement(typed_ast.FunctionDeclaration{
        identifier: typed_ast.Identifier{ name: 'test', span: span.point_span(0, 0) }
        params:     [
            typed_ast.FunctionParameter{ identifier: typed_ast.Identifier{ name: 'a', span: span.point_span(0, 0) } },
            typed_ast.FunctionParameter{ identifier: typed_ast.Identifier{ name: 'b', span: span.point_span(0, 0) } },
        ]
        body:       block
        span:       span.point_span(0, 0)
    })

    outer_block := typed_ast.Expression(typed_ast.BlockExpression{
        body: [
            typed_ast.BlockItem{ is_statement: true, statement: fn_decl },
            typed_ast.BlockItem{ is_statement: false, expression: block },
        ]
        span: span.point_span(0, 0)
    })

    // Compile with the real compiler
    type_env := types.TypeEnv{}
    fl := flags.Flags{}

    program := bytecode.compile(outer_block, type_env, fl) or {
        println('Compile error: ${err}')
        return
    }
    println('Compiled ${program.code.len} instructions')

    // Test if expression
    if_expr := typed_ast.Expression(typed_ast.IfExpression{
        condition: typed_ast.Expression(typed_ast.BooleanLiteral{ value: true, span: span.point_span(0, 0) })
        body:      block
        else_body: num
        span:      span.point_span(0, 0)
    })

    program2 := bytecode.compile(if_expr, type_env, fl) or {
        println('Compile error: ${err}')
        return
    }
    println('Compiled if: ${program2.code.len} instructions')

    // Test export declaration (recursive Statement)
    export_decl := typed_ast.Statement(typed_ast.ExportDeclaration{
        declaration: fn_decl
        span:        span.point_span(0, 0)
    })

    export_block := typed_ast.Expression(typed_ast.BlockExpression{
        body: [
            typed_ast.BlockItem{ is_statement: true, statement: export_decl },
        ]
        span: span.point_span(0, 0)
    })

    program3 := bytecode.compile(export_block, type_env, fl) or {
        println('Compile error: ${err}')
        return
    }
    println('Compiled export: ${program3.code.len} instructions')

    // Test match expression
    match_expr := typed_ast.Expression(typed_ast.MatchExpression{
        subject: num
        arms:    [
            typed_ast.MatchArm{
                pattern: typed_ast.Expression(typed_ast.NumberLiteral{ value: '42', span: span.point_span(0, 0) })
                body:    str
            },
            typed_ast.MatchArm{
                pattern: typed_ast.Expression(typed_ast.WildcardPattern{ span: span.point_span(0, 0) })
                body:    num
            },
        ]
        span:    span.point_span(0, 0)
    })

    program4 := bytecode.compile(match_expr, type_env, fl) or {
        println('Compile error: ${err}')
        return
    }
    println('Compiled match: ${program4.code.len} instructions')

    // Test OrExpression with TypeOption
    or_expr := typed_ast.Expression(typed_ast.OrExpression{
        expression:    num
        body:          str
        resolved_type: type_def.Type(type_def.TypeOption{ inner: type_def.t_int() })
        span:          span.point_span(0, 0)
    })

    program5 := bytecode.compile(or_expr, type_env, fl) or {
        println('Compile error: ${err}')
        return
    }
    println('Compiled or: ${program5.code.len} instructions')

    // Test deeply nested blocks
    deep := typed_ast.Expression(typed_ast.BlockExpression{
        body: [
            typed_ast.BlockItem{
                is_statement: false
                expression:   typed_ast.Expression(typed_ast.BlockExpression{
                    body: [
                        typed_ast.BlockItem{
                            is_statement: false
                            expression:   typed_ast.Expression(typed_ast.BlockExpression{
                                body: [
                                    typed_ast.BlockItem{ is_statement: true, statement: export_decl },
                                    typed_ast.BlockItem{ is_statement: false, expression: if_expr },
                                ]
                                span: span.point_span(0, 0)
                            })
                        },
                    ]
                    span: span.point_span(0, 0)
                })
            },
        ]
        span: span.point_span(0, 0)
    })

    program6 := bytecode.compile(deep, type_env, fl) or {
        println('Compile error: ${err}')
        return
    }
    println('Compiled deep: ${program6.code.len} instructions')

    // Test function expression
    fn_expr := typed_ast.Expression(typed_ast.FunctionExpression{
        params: [
            typed_ast.FunctionParameter{ identifier: typed_ast.Identifier{ name: 'x', span: span.point_span(0, 0) } },
        ]
        body:   typed_ast.Expression(typed_ast.BinaryExpression{
            left:  ident
            right: num
            op:    typed_ast.Operator{ kind: .punc_plus }
            span:  span.point_span(0, 0)
        })
        span:   span.point_span(0, 0)
    })

    program7 := bytecode.compile(fn_expr, type_env, fl) or {
        println('Compile error: ${err}')
        return
    }
    println('Compiled fn: ${program7.code.len} instructions')

    // Test function call
    call_expr := typed_ast.Expression(typed_ast.FunctionCallExpression{
        identifier: typed_ast.Identifier{ name: 'test', span: span.point_span(0, 0) }
        arguments:  [num, str]
        span:       span.point_span(0, 0)
    })

    // Need to set up local for this to work
    block_with_call := typed_ast.Expression(typed_ast.BlockExpression{
        body: [
            typed_ast.BlockItem{ is_statement: true, statement: fn_decl },
            typed_ast.BlockItem{ is_statement: false, expression: call_expr },
        ]
        span: span.point_span(0, 0)
    })

    program8 := bytecode.compile(block_with_call, type_env, fl) or {
        println('Compile error: ${err}')
        return
    }
    println('Compiled call: ${program8.code.len} instructions')

    println('All tests passed!')
}
