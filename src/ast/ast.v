module ast

import token
import span { Span }

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

pub struct ErrorNode {
pub:
	message string
	span    Span @[required]
}

pub struct Identifier {
pub:
	name string
	span Span @[required]
}

pub struct TypeIdentifier {
pub:
	is_array     bool
	is_option    bool
	is_function  bool
	identifier   Identifier
	element_type ?&TypeIdentifier
	param_types  []TypeIdentifier
	return_type  ?&TypeIdentifier
	error_type   ?&TypeIdentifier
	span         Span @[required]
}

pub struct Operator {
pub:
	kind token.Kind
}

pub struct VariableBinding {
pub:
	identifier Identifier
	typ        ?TypeIdentifier
	init       Expression
	span       Span @[required]
}

pub struct FunctionParameter {
pub:
	identifier Identifier
	typ        ?TypeIdentifier
}

pub struct FunctionDeclaration {
pub:
	identifier  Identifier
	return_type ?TypeIdentifier
	error_type  ?TypeIdentifier
	params      []FunctionParameter
	body        Expression
	span        Span @[required]
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
	return_type ?TypeIdentifier
	error_type  ?TypeIdentifier
	params      []FunctionParameter
	body        Expression
	span        Span @[required]
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

pub struct UnaryExpression {
pub:
	expression Expression
	op         Operator
	span       Span @[required]
}

pub struct ArrayExpression {
pub:
	elements []Expression
	span     Span @[required]
}

pub struct PropertyAccessExpression {
pub:
	left  Expression
	right Expression
	span  Span @[required]
}

pub struct FunctionCallExpression {
pub:
	identifier Identifier
	arguments  []Expression
	span       Span @[required]
}

pub struct BlockExpression {
pub:
	body []Node
	span Span @[required]
}

pub type Expression = ArrayExpression
	| BinaryExpression
	| BlockExpression
	| BooleanLiteral
	| ErrorNode
	| FunctionCallExpression
	| FunctionExpression
	| Identifier
	| IfExpression
	| NumberLiteral
	| PropertyAccessExpression
	| StringLiteral
	| UnaryExpression

pub type Node = Statement | Expression

pub fn node_span(node Node) Span {
	return match node {
		Statement { node.span }
		Expression { node.span }
	}
}
