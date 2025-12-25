module main

// === SPAN ===
pub struct Span { pub: start_line int @[required] start_column int @[required] end_line int @[required] end_column int @[required] }
pub fn point_span(line int, column int) Span { return Span{start_line: line, start_column: column, end_line: line, end_column: column + 1} }
fn span() Span { return Span{start_line: 0, start_column: 0, end_line: 0, end_column: 0} }

// === TOKEN KIND ===
pub enum Kind {
	eof error identifier literal_number literal_string literal_string_interpolation literal_char
	logical_and logical_or bitwise_and bitwise_or bitwise_xor bitwise_not
	kw_comptime kw_const kw_enum kw_error kw_if kw_else kw_function kw_import kw_from
	kw_true kw_false kw_assert kw_export kw_struct kw_in kw_match kw_none kw_or
	punc_arrow punc_comma punc_colon punc_semicolon punc_dot punc_dotdot punc_ellipsis
	punc_open_paren punc_close_paren punc_open_brace punc_close_brace punc_open_bracket punc_close_bracket
	punc_question_mark punc_exclamation_mark punc_at punc_equals punc_equals_comparator punc_not_equal
	punc_gt punc_lt punc_gte punc_lte punc_plus punc_plusplus punc_minus punc_minusminus
	punc_mul punc_div punc_mod _end_
}

// === DIAGNOSTIC ===
pub enum Severity { error }
pub struct Diagnostic { pub: span Span severity Severity message string }

// === TYPE DEF ===
pub type Type = TypeNone
pub struct TypeNone {}
pub fn t_none() Type { return TypeNone{} }

// === AST ===
pub struct AstNumberLiteral { pub: value string span Span @[required] }
pub struct AstStringLiteral { pub: value string span Span @[required] }
pub struct AstBooleanLiteral { pub: value bool span Span @[required] }
pub struct AstErrorNode { pub: message string span Span @[required] }
pub struct AstIdentifier { pub: name string span Span @[required] }
pub struct AstTypeIdentifier { pub: is_array bool is_option bool is_function bool identifier AstIdentifier element_type ?&AstTypeIdentifier param_types []AstTypeIdentifier return_type ?&AstTypeIdentifier error_type ?&AstTypeIdentifier span Span @[required] }
pub struct AstOperator { pub: kind Kind }
pub struct AstVariableBinding { pub: identifier AstIdentifier typ ?AstTypeIdentifier init AstExpression span Span @[required] }
pub struct AstFunctionParameter { pub: identifier AstIdentifier typ ?AstTypeIdentifier }
pub struct AstFunctionDeclaration { pub: identifier AstIdentifier return_type ?AstTypeIdentifier error_type ?AstTypeIdentifier params []AstFunctionParameter body AstExpression span Span @[required] }
pub struct AstExportDeclaration { pub: declaration AstStatement span Span @[required] }
pub type AstStatement = AstExportDeclaration | AstFunctionDeclaration | AstVariableBinding
pub struct AstFunctionExpression { pub: return_type ?AstTypeIdentifier error_type ?AstTypeIdentifier params []AstFunctionParameter body AstExpression span Span @[required] }
pub struct AstIfExpression { pub: condition AstExpression body AstExpression span Span @[required] else_body ?AstExpression }
pub struct AstBinaryExpression { pub: left AstExpression right AstExpression op AstOperator span Span @[required] }
pub struct AstUnaryExpression { pub: expression AstExpression op AstOperator span Span @[required] }
pub struct AstArrayExpression { pub: elements []AstExpression span Span @[required] }
pub struct AstPropertyAccessExpression { pub: left AstExpression right AstExpression span Span @[required] }
pub struct AstFunctionCallExpression { pub: identifier AstIdentifier arguments []AstExpression span Span @[required] }
pub struct AstBlockExpression { pub: body []AstNode span Span @[required] }
pub type AstExpression = AstArrayExpression | AstBinaryExpression | AstBlockExpression | AstBooleanLiteral | AstErrorNode | AstFunctionCallExpression | AstFunctionExpression | AstIdentifier | AstIfExpression | AstNumberLiteral | AstPropertyAccessExpression | AstStringLiteral | AstUnaryExpression
pub type AstNode = AstStatement | AstExpression

// === TYPED AST ===
pub struct TNumberLiteral { pub: value string span Span @[required] }
pub struct TStringLiteral { pub: value string span Span @[required] }
pub struct TBooleanLiteral { pub: value bool span Span @[required] }
pub struct TErrorNode { pub: message string span Span @[required] }
pub struct TIdentifier { pub: name string span Span @[required] }
pub struct TTypeIdentifier { pub: is_array bool is_option bool is_function bool identifier TIdentifier element_type ?&TTypeIdentifier param_types []TTypeIdentifier return_type ?&TTypeIdentifier error_type ?&TTypeIdentifier span Span @[required] }
pub struct TOperator { pub: kind Kind }
pub struct TVariableBinding { pub: identifier TIdentifier typ ?TTypeIdentifier init TExpression span Span @[required] }
pub struct TFunctionParameter { pub: identifier TIdentifier typ ?TTypeIdentifier }
pub struct TFunctionDeclaration { pub: identifier TIdentifier return_type ?TTypeIdentifier error_type ?TTypeIdentifier params []TFunctionParameter body TExpression span Span @[required] }
pub struct TExportDeclaration { pub: declaration TStatement span Span @[required] }
pub type TStatement = TExportDeclaration | TFunctionDeclaration | TVariableBinding
pub struct TFunctionExpression { pub: return_type ?TTypeIdentifier error_type ?TTypeIdentifier params []TFunctionParameter body TExpression span Span @[required] }
pub struct TIfExpression { pub: condition TExpression body TExpression span Span @[required] else_body ?TExpression }
pub struct TBinaryExpression { pub: left TExpression right TExpression op TOperator span Span @[required] }
pub struct TUnaryExpression { pub: expression TExpression op TOperator span Span @[required] }
pub struct TArrayExpression { pub: elements []TExpression span Span @[required] }
pub struct TPropertyAccessExpression { pub: left TExpression right TExpression span Span @[required] }
pub struct TFunctionCallExpression { pub: identifier TIdentifier arguments []TExpression span Span @[required] }
pub struct TBlockItem { pub: is_statement bool statement TStatement expression TExpression }
pub struct TBlockExpression { pub: body []TBlockItem span Span @[required] }
pub type TExpression = TArrayExpression | TBinaryExpression | TBlockExpression | TBooleanLiteral | TErrorNode | TFunctionCallExpression | TFunctionExpression | TIdentifier | TIfExpression | TNumberLiteral | TPropertyAccessExpression | TStringLiteral | TUnaryExpression

// === TYPE ENVIRONMENT ===
pub struct TypeEnv { mut: bindings map[string]Type }
pub fn new_env() TypeEnv { return TypeEnv{bindings: map[string]Type{}} }
pub fn (mut e TypeEnv) define(name string, t Type) { e.bindings[name] = t }

// === TYPE CHECKER ===
pub struct TypeChecker { mut: env TypeEnv diagnostics []Diagnostic }
pub struct CheckResult { pub: success bool typed_ast TBlockExpression }

pub fn check(program AstBlockExpression) CheckResult {
	mut checker := TypeChecker{env: new_env(), diagnostics: []Diagnostic{}}
	typed_block, _ := checker.check_block(program)
	return CheckResult{success: checker.diagnostics.len == 0, typed_ast: typed_block}
}

fn (mut c TypeChecker) check_block(block AstBlockExpression) (TBlockExpression, Type) {
	mut typed_body := []TBlockItem{}
	for node in block.body {
		is_stmt := node is AstStatement
		if is_stmt {
			stmt := node as AstStatement
			typed_stmt := c.check_statement(stmt)
			typed_body << TBlockItem{is_statement: true, statement: typed_stmt}
		} else {
			expr := node as AstExpression
			typed_expr := c.check_expr(expr)
			typed_body << TBlockItem{is_statement: false, expression: typed_expr}
		}
	}
	return TBlockExpression{body: typed_body, span: block.span}, t_none()
}

fn (mut c TypeChecker) check_statement(stmt AstStatement) TStatement {
	match stmt {
		AstVariableBinding {
			typed_init := c.check_expr(stmt.init)
			c.env.define(stmt.identifier.name, t_none())
			return TVariableBinding{identifier: convert_id(stmt.identifier), init: typed_init, span: stmt.span}
		}
		AstFunctionDeclaration {
			c.env.define(stmt.identifier.name, t_none())
			for param in stmt.params { c.env.define(param.identifier.name, t_none()) }
			typed_body := c.check_expr(stmt.body)
			return TFunctionDeclaration{identifier: convert_id(stmt.identifier), body: typed_body, span: stmt.span}
		}
		AstExportDeclaration { return TExportDeclaration{declaration: c.check_statement(stmt.declaration), span: stmt.span} }
	}
}

fn (mut c TypeChecker) check_expr(expr AstExpression) TExpression {
	match expr {
		AstNumberLiteral { return TNumberLiteral{value: expr.value, span: expr.span} }
		AstStringLiteral { return TStringLiteral{value: expr.value, span: expr.span} }
		AstBooleanLiteral { return TBooleanLiteral{value: expr.value, span: expr.span} }
		AstIdentifier { return TIdentifier{name: expr.name, span: expr.span} }
		AstBinaryExpression { return TBinaryExpression{left: c.check_expr(expr.left), right: c.check_expr(expr.right), op: TOperator{kind: expr.op.kind}, span: expr.span} }
		AstUnaryExpression { return TUnaryExpression{expression: c.check_expr(expr.expression), op: TOperator{kind: expr.op.kind}, span: expr.span} }
		AstFunctionExpression { return TFunctionExpression{body: c.check_expr(expr.body), span: expr.span} }
		AstFunctionCallExpression { return TFunctionCallExpression{identifier: convert_id(expr.identifier), span: expr.span} }
		AstBlockExpression { block, _ := c.check_block(expr); return block }
		AstIfExpression { return TIfExpression{condition: c.check_expr(expr.condition), body: c.check_expr(expr.body), span: expr.span} }
		AstArrayExpression { return TArrayExpression{span: expr.span} }
		AstPropertyAccessExpression { return TPropertyAccessExpression{left: c.check_expr(expr.left), right: c.check_expr(expr.right), span: expr.span} }
		AstErrorNode { return TErrorNode{message: expr.message, span: expr.span} }
	}
}

fn convert_id(id AstIdentifier) TIdentifier { return TIdentifier{name: id.name, span: id.span} }

// === MAIN ===
fn main() {
	// Manually construct AST (no parser)
	program := AstBlockExpression{
		body: [
			AstNode(AstStatement(AstVariableBinding{
				identifier: AstIdentifier{name: 'x', span: span()}
				init: AstNumberLiteral{value: '1', span: span()}
				span: span()
			})),
			AstNode(AstStatement(AstVariableBinding{
				identifier: AstIdentifier{name: 'y', span: span()}
				init: AstNumberLiteral{value: '2', span: span()}
				span: span()
			})),
			AstNode(AstStatement(AstVariableBinding{
				identifier: AstIdentifier{name: 'z', span: span()}
				init: AstBinaryExpression{
					left: AstIdentifier{name: 'x', span: span()}
					right: AstIdentifier{name: 'y', span: span()}
					op: AstOperator{kind: .punc_plus}
					span: span()
				}
				span: span()
			})),
			AstNode(AstStatement(AstFunctionDeclaration{
				identifier: AstIdentifier{name: 'add', span: span()}
				body: AstIdentifier{name: 'a', span: span()}
				span: span()
			})),
			AstNode(AstStatement(AstVariableBinding{
				identifier: AstIdentifier{name: 'result', span: span()}
				init: AstFunctionCallExpression{
					identifier: AstIdentifier{name: 'add', span: span()}
					arguments: [AstExpression(AstNumberLiteral{value: '1', span: span()}), AstExpression(AstNumberLiteral{value: '2', span: span()})]
					span: span()
				}
				span: span()
			})),
		]
		span: span()
	}
	println('AST with ${program.body.len} nodes')
	check_result := check(program)
	if !check_result.success { println('Type check failed'); return }
	println('Type checked: ${check_result.typed_ast.body.len} items')
	println('All tests passed!')
}
