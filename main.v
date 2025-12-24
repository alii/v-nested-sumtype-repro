module main

import src.ast
import src.compiler
import src.span { Span }

fn main() {
	// Build a complex AST
	num := ast.Expression(ast.NumberLiteral{ value: '42', span: Span{} })
	str := ast.Expression(ast.StringLiteral{ value: 'hello', span: Span{} })

	var_bind := ast.Statement(ast.VariableBinding{
		name: 'x'
		init: num
		span: Span{}
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
		name:   'test'
		params: ['a', 'b']
		body:   block
		span:   Span{}
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

	// More complex nesting
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
}
