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

// === TOKEN ===
pub struct Token { pub: kind Kind literal ?string line int column int }
pub fn (t &Token) str() string { if literal := t.literal { if t.kind == .literal_string { return '\'${literal}\'' } }; return t.literal or { t.kind.str() } }

pub const keyword_map = { 'fn': Kind.kw_function }
fn is_name_char(c u8) bool { return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_` || c.is_digit() }
pub fn is_valid_identifier(identifier string, _ bool) bool {
	if identifier.len == 0 { return false }
	if !identifier[0].is_letter() && identifier[0] != `_` { return false }
	for i := 1; i < identifier.len; i++ { if !is_name_char(identifier[i]) { return false } }
	return true
}
pub fn match_keyword(identifier ?string) ?Kind { if unwrapped := identifier { return keyword_map[unwrapped] or { return none } }; return none }
pub fn is_quote(c char) bool { return c == `'` }

// === SCANNER STATE ===
pub struct ScannerState { mut: pos int column int line int }
pub fn (mut s ScannerState) get_pos() int { return s.pos }
pub fn (mut s ScannerState) incr_pos() { s.pos++ }
pub fn (s ScannerState) get_line() int { return s.line }
pub fn (s ScannerState) get_column() int { return s.column }
pub fn (mut s ScannerState) incr_line() { s.line++; s.column = 0 }
pub fn (mut s ScannerState) incr_column() { s.column++ }

// === SCANNER ===
@[heap]
pub struct Scanner { input string mut: state &ScannerState diagnostics []Diagnostic token_start_column int token_start_line int }

pub fn new_scanner(input string) &Scanner { return &Scanner{input: input, state: &ScannerState{}, diagnostics: []Diagnostic{}} }
fn (mut s Scanner) add_error(message string) { s.diagnostics << error_at(s.state.get_line(), s.state.get_column(), message) }
pub fn (sc Scanner) get_diagnostics() []Diagnostic { return sc.diagnostics }
fn (mut s Scanner) skip_whitespace() { for s.state.get_pos() < s.input.len { ch := s.peek_char(); if ch == ` ` || ch == `\t` || ch == `\n` { s.incr_pos() } else { break } } }

pub fn (mut s Scanner) scan_next() Token {
	s.skip_whitespace()
	s.token_start_column = s.state.get_column()
	s.token_start_line = s.state.get_line()
	if s.state.get_pos() == s.input.len { return s.new_token(.eof, none) }
	ch := s.peek_char()
	s.incr_pos()
	if is_valid_identifier(ch.ascii_str(), false) {
		identifier := s.scan_identifier(ch)
		if unwrapped := identifier.literal { if keyword_kind := match_keyword(unwrapped) { return s.new_token(keyword_kind, none) } }
		return identifier
	}
	if ch == `-` && s.peek_char() == `>` { s.incr_pos(); return s.new_token(.punc_arrow, none) }
	if ch == `.` && s.peek_char() == `.` { s.incr_pos(); return s.new_token(.punc_dotdot, none) }
	if ch.is_alnum() { if ch.is_digit() { return s.scan_number(ch) }; return s.scan_identifier(ch) }
	if is_quote(ch) {
		mut result := ''
		for { next := s.peek_char(); if next == 0 || next == `\n` || next == ch { if next == ch { s.incr_pos() }; break }; s.incr_pos(); result += next.ascii_str() }
		return s.new_token(.literal_string, result)
	}
	return match ch {
		`,` { s.new_token(.punc_comma, none) }
		`(` { s.new_token(.punc_open_paren, none) }
		`)` { s.new_token(.punc_close_paren, none) }
		`{` { s.new_token(.punc_open_brace, none) }
		`}` { s.new_token(.punc_close_brace, none) }
		`[` { s.new_token(.punc_open_bracket, none) }
		`]` { s.new_token(.punc_close_bracket, none) }
		`;` { s.new_token(.punc_semicolon, none) }
		`.` { s.new_token(.punc_dot, none) }
		`+` { s.new_token(.punc_plus, none) }
		`-` { s.new_token(.punc_minus, none) }
		`*` { s.new_token(.punc_mul, none) }
		`%` { s.new_token(.punc_mod, none) }
		`!` { s.new_token(.punc_exclamation_mark, none) }
		`?` { s.new_token(.punc_question_mark, none) }
		`:` { s.new_token(.punc_colon, none) }
		`>` { s.new_token(.punc_gt, none) }
		`<` { s.new_token(.punc_lt, none) }
		`/` { s.new_token(.punc_div, none) }
		`|` { s.new_token(.bitwise_or, none) }
		`=` { s.new_token(.punc_equals, none) }
		else { s.add_error("Unexpected character '${ch.ascii_str()}'"); return s.new_token(.error, ch.ascii_str()) }
	}
}

pub fn (mut s Scanner) scan_all() []Token { mut r := []Token{}; for { t := s.scan_next(); r << t; if t.kind == .eof { break } }; return r }
fn (mut s Scanner) new_token(kind Kind, literal ?string) Token { return Token{kind: kind, literal: literal, line: s.token_start_line, column: s.token_start_column} }
fn (mut s Scanner) scan_identifier(from u8) Token { mut result := from.ascii_str(); for { next := result + s.peek_char().ascii_str(); if is_valid_identifier(next, false) { s.incr_pos(); result = next } else { break } }; return s.new_token(.identifier, result) }
fn (mut s Scanner) scan_number(from u8) Token { mut result := from.ascii_str(); for { next := s.peek_char(); if next.is_digit() { s.incr_pos(); result += next.ascii_str() } else { break } }; return s.new_token(.literal_number, result) }
fn (mut s Scanner) peek_char() u8 { if s.state.get_pos() >= s.input.len { return 0 }; return s.input[s.state.get_pos()] }
pub fn (mut s Scanner) incr_pos() { if s.input[s.state.get_pos()] == `\n` { s.state.incr_line() } else { s.state.incr_column() }; s.state.incr_pos() }

fn error_at(line int, column int, message string) Diagnostic { return Diagnostic{span: point_span(line, column), severity: .error, message: message} }

// === PARSER (types only, no execution) ===
pub enum ParseContext { top_level block function_params }
pub struct ParseResult { pub: ast AstBlockExpression diagnostics []Diagnostic }
pub struct Parser { tokens []Token mut: index int current_token Token diagnostics []Diagnostic context_stack []ParseContext prev_token_end_line int prev_token_end_column int }

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
	// Use scanner
	source := 'x = 1\ny = 2\n'
	mut s := new_scanner(source)
	tokens := s.scan_all()
	println('Scanned ${tokens.len} tokens')

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
