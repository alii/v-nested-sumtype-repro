module ast

import src.span { Span }

// Statements
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

pub struct TypePatternBinding {
pub:
	typ  string
	init Expression
	span Span @[required]
}

pub struct FunctionDeclaration {
pub:
	name   string
	params []string
	body   Expression
	span   Span @[required]
}

pub struct StructDeclaration {
pub:
	name   string
	fields []string
	span   Span @[required]
}

pub struct EnumDeclaration {
pub:
	name     string
	variants []string
	span     Span @[required]
}

pub struct ImportDeclaration {
pub:
	path string
	span Span @[required]
}

pub struct ExportDeclaration {
pub:
	declaration Statement
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

// Expressions
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

pub struct NoneExpression {
pub:
	span Span @[required]
}

pub struct Identifier {
pub:
	name string
	span Span @[required]
}

pub struct BinaryExpression {
pub:
	left  Expression
	op    string
	right Expression
	span  Span @[required]
}

pub struct UnaryExpression {
pub:
	op   string
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

pub struct FunctionExpression {
pub:
	params []string
	body   Expression
	span   Span @[required]
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
	array Expression
	index Expression
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
	name   string
	fields []Expression
	span   Span @[required]
}

pub struct MatchExpression {
pub:
	subject Expression
	arms    []Expression
	span    Span @[required]
}

pub struct OrExpression {
pub:
	expr Expression
	body Expression
	span Span @[required]
}

pub struct ErrorExpression {
pub:
	expr Expression
	span Span @[required]
}

pub struct SpreadExpression {
pub:
	expr ?Expression
	span Span @[required]
}

pub struct RangeExpression {
pub:
	start Expression
	end   Expression
	span  Span @[required]
}

pub struct AssertExpression {
pub:
	expr    Expression
	message Expression
	span    Span @[required]
}

pub struct InterpolatedString {
pub:
	parts []Expression
	span  Span @[required]
}

pub struct ErrorNode {
pub:
	message string
	span    Span @[required]
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
	| RangeExpression
	| SpreadExpression
	| StringLiteral
	| StructInitExpression
	| UnaryExpression
	| WildcardPattern
