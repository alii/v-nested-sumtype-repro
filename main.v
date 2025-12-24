module main

// Minimal reproduction of V segfault with nested sum types
// Bug: Segfaults with -prod (GCC -O3) on Linux x86_64
// Works fine with -O2 or on macOS

// Simple span type
pub struct Span {
pub:
	line int
	col  int
}

fn s() Span {
	return Span{ line: 0, col: 0 }
}

// ============================================================================
// Statement sum type (8 variants, one recursive via ExportDeclaration)
// ============================================================================

pub struct VariableBinding {
pub:
	name string
	init Expression
	span Span @[required]
}

pub struct ConstBinding {
pub:
	name string
	init Expression
	span Span @[required]
}

pub struct FunctionDeclaration {
pub:
	name string
	body Expression
	span Span @[required]
}

pub struct StructDeclaration {
pub:
	name string
	span Span @[required]
}

pub struct EnumDeclaration {
pub:
	name string
	span Span @[required]
}

pub struct ImportDeclaration {
pub:
	path string
	span Span @[required]
}

pub struct TypePatternBinding {
pub:
	init Expression
	span Span @[required]
}

pub struct ExportDeclaration {
pub:
	declaration Statement // RECURSIVE - Statement contains Statement
	span        Span @[required]
}

pub type Statement = ConstBinding
	| EnumDeclaration
	| ExportDeclaration
	| FunctionDeclaration
	| ImportDeclaration
	| StructDeclaration
	| TypePatternBinding
	| VariableBinding

// ============================================================================
// Expression sum type (27 variants)
// ============================================================================

pub struct NumberLiteral {
pub:
	value string
	span  Span @[required]
}

pub struct StringLiteral {
pub:
	value string
	span  Span @[required]
}

pub struct BooleanLiteral {
pub:
	value bool
	span  Span @[required]
}

pub struct Identifier {
pub:
	name string
	span Span @[required]
}

pub struct BinaryExpression {
pub:
	left  Expression
	right Expression
	span  Span @[required]
}

pub struct UnaryExpression {
pub:
	expr Expression
	span Span @[required]
}

pub struct IfExpression {
pub:
	condition Expression
	body      Expression
	else_body ?Expression
	span      Span @[required]
}

pub struct MatchExpression {
pub:
	subject Expression
	span    Span @[required]
}

pub struct FunctionExpression {
pub:
	body Expression
	span Span @[required]
}

pub struct FunctionCallExpression {
pub:
	name string
	args []Expression
	span Span @[required]
}

pub struct ArrayExpression {
pub:
	elements []Expression
	span     Span @[required]
}

pub struct ArrayIndexExpression {
pub:
	expr  Expression
	index Expression
	span  Span @[required]
}

pub struct RangeExpression {
pub:
	start Expression
	end   Expression
	span  Span @[required]
}

pub struct PropertyAccessExpression {
pub:
	left  Expression
	right Expression
	span  Span @[required]
}

pub struct StructInitExpression {
pub:
	name string
	span Span @[required]
}

pub struct NoneExpression {
pub:
	span Span @[required]
}

pub struct ErrorNode {
pub:
	message string
	span    Span @[required]
}

pub struct ErrorExpression {
pub:
	expr Expression
	span Span @[required]
}

pub struct OrExpression {
pub:
	expr Expression
	body Expression
	span Span @[required]
}

pub struct PropagateNoneExpression {
pub:
	expr Expression
	span Span @[required]
}

pub struct InterpolatedString {
pub:
	parts []Expression
	span  Span @[required]
}

pub struct TypeIdentifier {
pub:
	name string
	span Span @[required]
}

pub struct AssertExpression {
pub:
	expr Expression
	span Span @[required]
}

pub struct WildcardPattern {
pub:
	span Span @[required]
}

pub struct OrPattern {
pub:
	patterns []Expression
	span     Span @[required]
}

pub struct SpreadExpression {
pub:
	expr ?Expression
	span Span @[required]
}

// BlockItem bridges Statement and Expression
pub struct BlockItem {
pub:
	is_statement bool
	statement    Statement
	expression   Expression
}

pub struct BlockExpression {
pub:
	body []BlockItem
	span Span @[required]
}

pub type Expression = ArrayExpression
	| ArrayIndexExpression
	| AssertExpression
	| BinaryExpression
	| BlockExpression
	| BooleanLiteral
	| ErrorExpression
	| ErrorNode
	| FunctionCallExpression
	| FunctionExpression
	| Identifier
	| IfExpression
	| InterpolatedString
	| MatchExpression
	| NoneExpression
	| NumberLiteral
	| OrExpression
	| OrPattern
	| PropertyAccessExpression
	| PropagateNoneExpression
	| RangeExpression
	| SpreadExpression
	| StringLiteral
	| StructInitExpression
	| TypeIdentifier
	| UnaryExpression
	| WildcardPattern

// ============================================================================
// Functions that iterate over these types (triggers the bug)
// ============================================================================

fn process_statement(stmt Statement) int {
	return match stmt {
		VariableBinding { process_expression(stmt.init) }
		ConstBinding { process_expression(stmt.init) }
		FunctionDeclaration { process_expression(stmt.body) }
		StructDeclaration { 1 }
		EnumDeclaration { 1 }
		ImportDeclaration { 1 }
		TypePatternBinding { process_expression(stmt.init) }
		ExportDeclaration { process_statement(stmt.declaration) } // Recursive!
	}
}

fn process_expression(expr Expression) int {
	return match expr {
		NumberLiteral { 1 }
		StringLiteral { 1 }
		BooleanLiteral { 1 }
		Identifier { 1 }
		BinaryExpression { process_expression(expr.left) + process_expression(expr.right) }
		UnaryExpression { process_expression(expr.expr) }
		IfExpression {
			mut result := process_expression(expr.condition) + process_expression(expr.body)
			if else_body := expr.else_body {
				result += process_expression(else_body)
			}
			result
		}
		MatchExpression { process_expression(expr.subject) }
		FunctionExpression { process_expression(expr.body) }
		FunctionCallExpression {
			mut result := 0
			for arg in expr.args {
				result += process_expression(arg)
			}
			result
		}
		ArrayExpression {
			mut result := 0
			for elem in expr.elements {
				result += process_expression(elem)
			}
			result
		}
		ArrayIndexExpression { process_expression(expr.expr) + process_expression(expr.index) }
		RangeExpression { process_expression(expr.start) + process_expression(expr.end) }
		PropertyAccessExpression { process_expression(expr.left) + process_expression(expr.right) }
		StructInitExpression { 1 }
		NoneExpression { 0 }
		ErrorNode { 0 }
		ErrorExpression { process_expression(expr.expr) }
		OrExpression { process_expression(expr.expr) + process_expression(expr.body) }
		PropagateNoneExpression { process_expression(expr.expr) }
		InterpolatedString {
			mut result := 0
			for part in expr.parts {
				result += process_expression(part)
			}
			result
		}
		TypeIdentifier { 1 }
		AssertExpression { process_expression(expr.expr) }
		WildcardPattern { 1 }
		OrPattern {
			mut result := 0
			for p in expr.patterns {
				result += process_expression(p)
			}
			result
		}
		SpreadExpression {
			if e := expr.expr {
				process_expression(e)
			} else {
				0
			}
		}
		BlockExpression {
			mut result := 0
			for item in expr.body {
				if item.is_statement {
					result += process_statement(item.statement)
				} else {
					result += process_expression(item.expression)
				}
			}
			result
		}
	}
}

fn main() {
	// Create a complex nested structure
	inner_expr := Expression(BinaryExpression{
		left:  Expression(NumberLiteral{ value: '1', span: s() })
		right: Expression(NumberLiteral{ value: '2', span: s() })
		span:  s()
	})

	func_decl := Statement(FunctionDeclaration{
		name: 'test'
		body: inner_expr
		span: s()
	})

	export_decl := Statement(ExportDeclaration{
		declaration: func_decl // Recursive statement
		span:        s()
	})

	block := BlockExpression{
		body: [
			BlockItem{
				is_statement: true
				statement:    export_decl
				expression:   Expression(NoneExpression{ span: s() })
			},
			BlockItem{
				is_statement: false
				statement:    Statement(VariableBinding{ name: '', init: Expression(NoneExpression{ span: s() }), span: s() })
				expression:   inner_expr
			},
		]
		span: s()
	}

	println('Processing block with ${block.body.len} items...')
	result := process_expression(Expression(block))
	println('Result: ${result}')
	println('Success!')
}
