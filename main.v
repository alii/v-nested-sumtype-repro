module main

// More realistic repro with many variants like the real AST

struct Span {
	start_line   int
	start_column int
	end_line     int
	end_column   int
}

// Statements (8 variants like real code)
struct VariableBinding {
	name string
	init Expression
	span Span
}

struct ConstBinding {
	name string
	init Expression
	span Span
}

struct TypePatternBinding {
	typ  string
	init Expression
	span Span
}

struct FunctionDeclaration {
	name   string
	params []string
	body   Expression
	span   Span
}

struct StructDeclaration {
	name   string
	fields []string
	span   Span
}

struct EnumDeclaration {
	name     string
	variants []string
	span     Span
}

struct ImportDeclaration {
	path string
	span Span
}

struct ExportDeclaration {
	decl Statement
	span Span
}

type Statement = ConstBinding
	| EnumDeclaration
	| ExportDeclaration
	| FunctionDeclaration
	| ImportDeclaration
	| StructDeclaration
	| TypePatternBinding
	| VariableBinding

// Expressions (25+ variants like real code)
struct NumberLiteral {
	value string
	span  Span
}

struct StringLiteral {
	value string
	span  Span
}

struct BooleanLiteral {
	value bool
	span  Span
}

struct NoneExpression {
	span Span
}

struct Identifier {
	name string
	span Span
}

struct BinaryExpression {
	left  Expression
	op    string
	right Expression
	span  Span
}

struct UnaryExpression {
	op   string
	expr Expression
	span Span
}

struct IfExpression {
	condition Expression
	body      Expression
	else_body ?Expression
	span      Span
}

struct BlockExpression {
	body []Node
	span Span
}

struct FunctionExpression {
	params []string
	body   Expression
	span   Span
}

struct FunctionCallExpression {
	name string
	args []Expression
	span Span
}

struct ArrayExpression {
	elements []Expression
	span     Span
}

struct ArrayIndexExpression {
	array Expression
	index Expression
	span  Span
}

struct PropertyAccessExpression {
	left  Expression
	right Expression
	span  Span
}

struct StructInitExpression {
	name   string
	fields []Expression
	span   Span
}

struct MatchExpression {
	subject Expression
	arms    []Expression
	span    Span
}

struct OrExpression {
	expr Expression
	body Expression
	span Span
}

struct ErrorExpression {
	expr Expression
	span Span
}

struct SpreadExpression {
	expr ?Expression
	span Span
}

struct RangeExpression {
	start Expression
	end   Expression
	span  Span
}

struct AssertExpression {
	expr    Expression
	message Expression
	span    Span
}

struct InterpolatedString {
	parts []Expression
	span  Span
}

struct ErrorNode {
	message string
	span    Span
}

struct WildcardPattern {
	span Span
}

struct OrPattern {
	patterns []Expression
	span     Span
}

type Expression = ArrayExpression
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
	| RangeExpression
	| SpreadExpression
	| StringLiteral
	| StructInitExpression
	| UnaryExpression
	| WildcardPattern

type Node = Statement | Expression

fn node_span(node Node) Span {
	return match node {
		Statement { node.span }
		Expression { node.span }
	}
}

fn compile_node(node Node) int {
	match node {
		Statement { return compile_statement(node) }
		Expression { return compile_expr(node) }
	}
}

fn compile_statement(stmt Statement) int {
	match stmt {
		VariableBinding { return compile_expr(stmt.init) }
		ConstBinding { return compile_expr(stmt.init) }
		TypePatternBinding { return compile_expr(stmt.init) }
		FunctionDeclaration { return compile_expr(stmt.body) }
		StructDeclaration { return 0 }
		EnumDeclaration { return 0 }
		ImportDeclaration { return 0 }
		ExportDeclaration { return compile_statement(stmt.decl) }
	}
}

fn compile_expr(expr Expression) int {
	match expr {
		BlockExpression {
			mut sum := 0
			for i, node in expr.body {
				is_last := i == expr.body.len - 1
				sum += compile_node(node)

				if !is_last {
					match node {
						Expression { sum += 1 }
						Statement {}
					}
				}
			}

			if expr.body.len == 0 {
				sum += 100
			} else {
				match expr.body[expr.body.len - 1] {
					Statement { sum += 100 }
					Expression {}
				}
			}
			return sum
		}
		NumberLiteral { return 1 }
		StringLiteral { return 1 }
		BooleanLiteral { return 1 }
		NoneExpression { return 0 }
		Identifier { return 1 }
		BinaryExpression { return compile_expr(expr.left) + compile_expr(expr.right) }
		UnaryExpression { return compile_expr(expr.expr) }
		IfExpression {
			sum := compile_expr(expr.condition) + compile_expr(expr.body)
			if e := expr.else_body {
				return sum + compile_expr(e)
			}
			return sum
		}
		FunctionExpression { return compile_expr(expr.body) }
		FunctionCallExpression {
			mut sum := 0
			for arg in expr.args {
				sum += compile_expr(arg)
			}
			return sum
		}
		ArrayExpression {
			mut sum := 0
			for elem in expr.elements {
				sum += compile_expr(elem)
			}
			return sum
		}
		ArrayIndexExpression { return compile_expr(expr.array) + compile_expr(expr.index) }
		PropertyAccessExpression { return compile_expr(expr.left) + compile_expr(expr.right) }
		StructInitExpression {
			mut sum := 0
			for field in expr.fields {
				sum += compile_expr(field)
			}
			return sum
		}
		MatchExpression {
			mut sum := compile_expr(expr.subject)
			for arm in expr.arms {
				sum += compile_expr(arm)
			}
			return sum
		}
		OrExpression { return compile_expr(expr.expr) + compile_expr(expr.body) }
		ErrorExpression { return compile_expr(expr.expr) }
		SpreadExpression {
			if e := expr.expr {
				return compile_expr(e)
			}
			return 0
		}
		RangeExpression { return compile_expr(expr.start) + compile_expr(expr.end) }
		AssertExpression { return compile_expr(expr.expr) + compile_expr(expr.message) }
		InterpolatedString {
			mut sum := 0
			for part in expr.parts {
				sum += compile_expr(part)
			}
			return sum
		}
		ErrorNode { return 0 }
		WildcardPattern { return 0 }
		OrPattern {
			mut sum := 0
			for p in expr.patterns {
				sum += compile_expr(p)
			}
			return sum
		}
	}
}

fn main() {
	// Build a complex AST
	num := Expression(NumberLiteral{ value: '42', span: Span{} })
	str := Expression(StringLiteral{ value: 'hello', span: Span{} })

	var_bind := Statement(VariableBinding{
		name: 'x'
		init: num
		span: Span{}
	})

	block := Expression(BlockExpression{
		body: [Node(var_bind), Node(num), Node(str)]
		span: Span{}
	})

	fn_decl := Statement(FunctionDeclaration{
		name:   'test'
		params: ['a', 'b']
		body:   block
		span:   Span{}
	})

	outer_block := Expression(BlockExpression{
		body: [Node(fn_decl), Node(block)]
		span: Span{}
	})

	result := compile_expr(outer_block)
	println('Result: ${result}')

	// More complex nesting
	if_expr := Expression(IfExpression{
		condition: Expression(BooleanLiteral{ value: true, span: Span{} })
		body:      block
		else_body: num
		span:      Span{}
	})

	result2 := compile_expr(if_expr)
	println('Result2: ${result2}')
}
