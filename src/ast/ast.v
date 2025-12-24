module ast

import token
import span { Span }

pub struct StringLiteral {
pub:
	value string
	span  Span @[required]
}

pub struct NumberLiteral {
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

pub struct TypeIdentifier {
pub:
	identifier Identifier
	span       Span @[required]
}

pub struct Operator {
pub:
	kind token.Kind
}

pub struct VariableBinding {
pub:
	identifier Identifier
	init       Expression
	span       Span @[required]
}

pub struct FunctionParameter {
pub:
	identifier Identifier
}

pub struct FunctionDeclaration {
pub:
	identifier Identifier
	params     []FunctionParameter
	body       Expression
	span       Span @[required]
}

pub struct ExportDeclaration {
pub:
	declaration Statement
	span        Span @[required]
}

pub type Statement = ExportDeclaration
	| FunctionDeclaration
	| VariableBinding

pub struct FunctionExpression {
pub:
	params []FunctionParameter
	body   Expression
	span   Span @[required]
}

pub struct IfExpression {
pub:
	condition Expression
	body      Expression
	span      Span @[required]
	else_body ?Expression
}

pub struct BinaryExpression {
pub:
	left  Expression
	right Expression
	op    Operator
	span  Span @[required]
}

pub struct ArrayExpression {
pub:
	elements []Expression
	span     Span @[required]
}

pub struct ArrayIndexExpression {
pub:
	expression Expression
	index      Expression
	span       Span @[required]
}

pub struct FunctionCallExpression {
pub:
	identifier Identifier
	arguments  []Expression
	span       Span @[required]
}

pub struct ErrorNode {
pub:
	message string
	span    Span @[required]
}

pub struct BlockExpression {
pub:
	body []Node
	span Span @[required]
}

pub type Expression = ArrayExpression
	| ArrayIndexExpression
	| BinaryExpression
	| BlockExpression
	| BooleanLiteral
	| ErrorNode
	| FunctionCallExpression
	| FunctionExpression
	| Identifier
	| IfExpression
	| NumberLiteral
	| StringLiteral

pub type Node = Statement | Expression

pub struct BlockItem {
pub:
	is_statement bool
	statement    Statement
	expression   Expression
}

pub fn node_span(node Node) Span {
	return match node {
		Statement { node.span }
		Expression { node.span }
	}
}
