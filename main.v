module main

import src.ast
import src.compiler
import src.checker
import src.span { Span }
import src.type_def

fn main() {
	// Build a complex AST
	num := ast.Expression(ast.NumberLiteral{ value: '42', span: Span{} })
	str := ast.Expression(ast.StringLiteral{ value: 'hello', span: Span{} })
	ident := ast.Expression(ast.Identifier{ name: 'x', span: Span{} })

	// Binary expression with operator
	bin_expr := ast.Expression(ast.BinaryExpression{
		left:  num
		right: ast.Expression(ast.NumberLiteral{ value: '10', span: Span{} })
		op:    ast.Operator{ kind: .punc_plus }
		span:  Span{}
	})

	// Unary expression
	unary_expr := ast.Expression(ast.UnaryExpression{
		expression: num
		op:         ast.Operator{ kind: .punc_minus }
		span:       Span{}
	})

	var_bind := ast.Statement(ast.VariableBinding{
		identifier: ast.Identifier{ name: 'x', span: Span{} }
		init:       num
		span:       Span{}
	})

	block := ast.Expression(ast.BlockExpression{
		body: [
			ast.BlockItem{ is_statement: true, statement: var_bind },
			ast.BlockItem{ is_statement: false, expression: num },
			ast.BlockItem{ is_statement: false, expression: str },
		]
		span: Span{}
	})

	fn_decl := ast.Statement(ast.FunctionDeclaration{
		identifier: ast.Identifier{ name: 'test', span: Span{} }
		params:     [
			ast.FunctionParameter{ identifier: ast.Identifier{ name: 'a', span: Span{} } },
			ast.FunctionParameter{ identifier: ast.Identifier{ name: 'b', span: Span{} } },
		]
		body:       block
		span:       Span{}
	})

	outer_block := ast.Expression(ast.BlockExpression{
		body: [
			ast.BlockItem{ is_statement: true, statement: fn_decl },
			ast.BlockItem{ is_statement: false, expression: block },
		]
		span: Span{}
	})

	result := compiler.compile(outer_block)
	println('Result: ${result}')

	// More complex nesting with IfExpression
	if_expr := ast.Expression(ast.IfExpression{
		condition: ast.Expression(ast.BooleanLiteral{ value: true, span: Span{} })
		body:      block
		else_body: num
		span:      Span{}
	})

	result2 := compiler.compile(if_expr)
	println('Result2: ${result2}')

	// Test with export declaration (recursive Statement)
	export_decl := ast.Statement(ast.ExportDeclaration{
		declaration: fn_decl
		span:        Span{}
	})

	export_block := ast.Expression(ast.BlockExpression{
		body: [
			ast.BlockItem{ is_statement: true, statement: export_decl },
		]
		span: Span{}
	})

	result3 := compiler.compile(export_block)
	println('Result3: ${result3}')

	// Test MatchExpression
	match_expr := ast.Expression(ast.MatchExpression{
		subject: num
		arms:    [
			ast.MatchArm{
				pattern: ast.Expression(ast.NumberLiteral{ value: '42', span: Span{} })
				body:    str
			},
			ast.MatchArm{
				pattern: ast.Expression(ast.WildcardPattern{ span: Span{} })
				body:    num
			},
		]
		span:    Span{}
	})

	result4 := compiler.compile(match_expr)
	println('Result4: ${result4}')

	// Test OrExpression with TypeOption
	or_expr := ast.Expression(ast.OrExpression{
		expression:    num
		body:          str
		resolved_type: type_def.Type(type_def.TypeOption{ inner: type_def.Type(type_def.TypeInt{}) })
		span:          Span{}
	})

	result5 := compiler.compile(or_expr)
	println('Result5: ${result5}')

	// Test PropagateNoneExpression
	prop_expr := ast.Expression(ast.PropagateNoneExpression{
		expression:    num
		resolved_type: type_def.Type(type_def.TypeOption{ inner: type_def.Type(type_def.TypeInt{}) })
		span:          Span{}
	})

	result6 := compiler.compile(prop_expr)
	println('Result6: ${result6}')

	// Test nested blocks with many items
	many_items := ast.Expression(ast.BlockExpression{
		body: [
			ast.BlockItem{ is_statement: false, expression: num },
			ast.BlockItem{ is_statement: false, expression: str },
			ast.BlockItem{ is_statement: false, expression: ident },
			ast.BlockItem{ is_statement: true, statement: var_bind },
			ast.BlockItem{ is_statement: false, expression: num },
			ast.BlockItem{ is_statement: true, statement: fn_decl },
			ast.BlockItem{ is_statement: false, expression: str },
		]
		span: Span{}
	})

	result7 := compiler.compile(many_items)
	println('Result7: ${result7}')

	// Test deeply nested structure
	deep := ast.Expression(ast.BlockExpression{
		body: [
			ast.BlockItem{
				is_statement: false
				expression:   ast.Expression(ast.BlockExpression{
					body: [
						ast.BlockItem{
							is_statement: false
							expression:   ast.Expression(ast.BlockExpression{
								body: [
									ast.BlockItem{ is_statement: true, statement: export_decl },
									ast.BlockItem{ is_statement: false, expression: if_expr },
								]
								span: Span{}
							})
						},
					]
					span: Span{}
				})
			},
		]
		span: Span{}
	})

	result8 := compiler.compile(deep)
	println('Result8: ${result8}')

	// Test binary expression
	result9 := compiler.compile(bin_expr)
	println('Result9: ${result9}')

	// Test unary expression
	result10 := compiler.compile(unary_expr)
	println('Result10: ${result10}')

	// Test block with binary and unary
	mixed_block := ast.Expression(ast.BlockExpression{
		body: [
			ast.BlockItem{ is_statement: true, statement: var_bind },
			ast.BlockItem{ is_statement: false, expression: bin_expr },
			ast.BlockItem{ is_statement: false, expression: unary_expr },
			ast.BlockItem{ is_statement: true, statement: export_decl },
			ast.BlockItem{ is_statement: false, expression: if_expr },
		]
		span: Span{}
	})

	result11 := compiler.compile(mixed_block)
	println('Result11: ${result11}')

	// Test logical operators
	and_expr := ast.Expression(ast.BinaryExpression{
		left:  ast.Expression(ast.BooleanLiteral{ value: true, span: Span{} })
		right: ast.Expression(ast.BooleanLiteral{ value: false, span: Span{} })
		op:    ast.Operator{ kind: .logical_and }
		span:  Span{}
	})

	result12 := compiler.compile(and_expr)
	println('Result12: ${result12}')

	// Also run type checking
	check_result := checker.check(outer_block) or {
		println('Check error: ${err}')
		return
	}
	println('Check1: ${check_result}')

	check_result2 := checker.check(if_expr) or {
		println('Check error: ${err}')
		return
	}
	println('Check2: ${check_result2}')

	check_result3 := checker.check(export_block) or {
		println('Check error: ${err}')
		return
	}
	println('Check3: ${check_result3}')

	check_result4 := checker.check(deep) or {
		println('Check error: ${err}')
		return
	}
	println('Check4: ${check_result4}')
}
