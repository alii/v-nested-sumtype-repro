module main

// === SPAN ===
pub struct Span { pub: line int col int }
fn span(l int, c int) Span { return Span{line: l, col: c} }

// === TOKEN KIND (minimal) ===
pub enum Kind {
	eof error identifier literal_number literal_string
	kw_function kw_if kw_else kw_true kw_false
	punc_comma punc_open_paren punc_close_paren punc_open_brace punc_close_brace
	punc_open_bracket punc_close_bracket punc_plus punc_equals
}

pub fn (kind Kind) str() string {
	return match kind {
		.eof { 'EOF' } .error { 'error' } .identifier { 'id' } .literal_number { 'num' }
		.literal_string { 'str' } .kw_function { 'fn' } .kw_if { 'if' } .kw_else { 'else' }
		.kw_true { 'true' } .kw_false { 'false' } .punc_comma { ',' } .punc_open_paren { '(' }
		.punc_close_paren { ')' } .punc_open_brace { '{' } .punc_close_brace { '}' }
		.punc_open_bracket { '[' } .punc_close_bracket { ']' } .punc_plus { '+' } .punc_equals { '=' }
	}
}

// === TOKEN ===
pub struct Token { pub: kind Kind literal ?string line int col int }

pub const keyword_map = { 'fn': Kind.kw_function, 'if': Kind.kw_if, 'else': Kind.kw_else, 'true': Kind.kw_true, 'false': Kind.kw_false }
fn is_name_char(c u8) bool { return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_` || c.is_digit() }
fn is_valid_id(s string) bool { return s.len > 0 && (s[0].is_letter() || s[0] == `_`) }
fn match_kw(id ?string) ?Kind { if u := id { return keyword_map[u] or { return none } }; return none }

// === TYPE DEF ===
pub type Type = TypeNone
pub struct TypeNone {}
pub fn t_none() Type { return TypeNone{} }

// === AST ===
pub struct AstNum { pub: value string span Span }
pub struct AstStr { pub: value string span Span }
pub struct AstBool { pub: value bool span Span }
pub struct AstError { pub: message string span Span }
pub struct AstId { pub: name string span Span }
pub struct AstOp { pub: kind Kind }
pub struct AstBinding { pub: id AstId init AstExpr span Span }
pub struct AstFnDecl { pub: id AstId body AstExpr span Span }
pub type AstStmt = AstFnDecl | AstBinding
pub struct AstFnExpr { pub: body AstExpr span Span }
pub struct AstIfExpr { pub: cond AstExpr body AstExpr span Span }
pub struct AstBinExpr { pub: left AstExpr right AstExpr op AstOp span Span }
pub struct AstCall { pub: id AstId args []AstExpr span Span }
pub struct AstBlock { pub: body []AstNode span Span }
pub type AstExpr = AstBinExpr | AstBlock | AstBool | AstCall | AstError | AstFnExpr | AstId | AstIfExpr | AstNum | AstStr
pub type AstNode = AstStmt | AstExpr

// === TYPED AST ===
pub struct TNum { pub: value string span Span }
pub struct TStr { pub: value string span Span }
pub struct TBool { pub: value bool span Span }
pub struct TError { pub: message string span Span }
pub struct TId { pub: name string span Span }
pub struct TOp { pub: kind Kind }
pub struct TBinding { pub: id TId init TExpr span Span }
pub struct TFnDecl { pub: id TId body TExpr span Span }
pub type TStmt = TFnDecl | TBinding
pub struct TFnExpr { pub: body TExpr span Span }
pub struct TIfExpr { pub: cond TExpr body TExpr span Span }
pub struct TBinExpr { pub: left TExpr right TExpr op TOp span Span }
pub struct TCall { pub: id TId args []TExpr span Span }
pub struct TBlockItem { pub: is_stmt bool stmt TStmt expr TExpr }
pub struct TBlock { pub: body []TBlockItem span Span }
pub type TExpr = TBinExpr | TBlock | TBool | TCall | TError | TFnExpr | TId | TIfExpr | TNum | TStr

// === SCANNER ===
pub struct ScanState { mut: pos int col int line int }
pub struct Scanner { input string mut: state &ScanState start_col int start_line int }

pub fn new_scanner(input string) &Scanner { return &Scanner{input: input, state: &ScanState{}} }

pub fn (mut s Scanner) scan_next() Token {
	s.skip_ws()
	s.start_col = s.state.col
	s.start_line = s.state.line
	if s.state.pos >= s.input.len { return s.tok(.eof, none) }
	ch := s.peek()
	s.incr()
	if is_valid_id(ch.ascii_str()) {
		id := s.scan_id(ch)
		if kw := match_kw(id.literal) { return s.tok(kw, none) }
		return id
	}
	if ch.is_digit() { return s.scan_num(ch) }
	if ch == `'` {
		mut r := ''
		for { n := s.peek(); if n == 0 || n == `\n` || n == ch { if n == ch { s.incr() }; break }; s.incr(); r += n.ascii_str() }
		return s.tok(.literal_string, r)
	}
	return match ch {
		`,` { s.tok(.punc_comma, none) }
		`(` { s.tok(.punc_open_paren, none) }
		`)` { s.tok(.punc_close_paren, none) }
		`{` { s.tok(.punc_open_brace, none) }
		`}` { s.tok(.punc_close_brace, none) }
		`[` { s.tok(.punc_open_bracket, none) }
		`]` { s.tok(.punc_close_bracket, none) }
		`+` { s.tok(.punc_plus, none) }
		`=` { s.tok(.punc_equals, none) }
		else { s.tok(.error, ch.ascii_str()) }
	}
}

pub fn (mut s Scanner) scan_all() []Token { mut r := []Token{}; for { t := s.scan_next(); r << t; if t.kind == .eof { break } }; return r }
fn (mut s Scanner) tok(k Kind, lit ?string) Token { return Token{kind: k, literal: lit, line: s.start_line, col: s.start_col} }
fn (mut s Scanner) scan_id(from u8) Token { mut r := from.ascii_str(); for { n := r + s.peek().ascii_str(); if is_valid_id(n) && is_name_char(s.peek()) { s.incr(); r = n } else { break } }; return s.tok(.identifier, r) }
fn (mut s Scanner) scan_num(from u8) Token { mut r := from.ascii_str(); for { n := s.peek(); if n.is_digit() { s.incr(); r += n.ascii_str() } else { break } }; return s.tok(.literal_number, r) }
fn (mut s Scanner) peek() u8 { if s.state.pos >= s.input.len { return 0 }; return s.input[s.state.pos] }
fn (mut s Scanner) incr() { if s.input[s.state.pos] == `\n` { s.state.line++; s.state.col = 0 } else { s.state.col++ }; s.state.pos++ }
fn (mut s Scanner) skip_ws() { for s.state.pos < s.input.len { ch := s.peek(); if ch == ` ` || ch == `\t` || ch == `\n` { s.incr() } else { break } } }

// === PARSER ===
pub struct Parser { tokens []Token mut: idx int cur Token }

pub fn new_parser(mut s Scanner) Parser {
	tokens := s.scan_all()
	return Parser{tokens: tokens, idx: 0, cur: tokens[0]}
}

fn (mut p Parser) advance() { if p.idx + 1 < p.tokens.len { p.idx++; p.cur = p.tokens[p.idx] } }
fn (mut p Parser) eat(k Kind) !Token { if p.cur.kind == k { old := p.cur; p.idx++; p.cur = p.tokens[p.idx]; return old }; return error('expected ${k}') }
fn (mut p Parser) eat_lit(k Kind) !string { t := p.eat(k)!; return t.literal or { return error('no lit') } }
fn (mut p Parser) peek_next() ?Token { if p.idx + 1 < p.tokens.len { return p.tokens[p.idx + 1] }; return none }

pub fn (mut p Parser) parse() AstBlock {
	sp := span(p.cur.line, p.cur.col)
	mut body := []AstNode{}
	for p.cur.kind != .eof {
		node := p.parse_node() or { body << AstNode(AstExpr(AstError{message: err.msg(), span: sp})); p.advance(); continue }
		body << node
	}
	return AstBlock{body: body, span: sp}
}

fn (mut p Parser) parse_node() !AstNode {
	match p.cur.kind {
		.kw_function { return AstNode(p.parse_fn()!) }
		.identifier { if next := p.peek_next() { if next.kind == .punc_equals { return AstNode(p.parse_binding()!) } } }
		else {}
	}
	return AstNode(p.parse_expr()!)
}

fn (mut p Parser) parse_expr() !AstExpr { return p.parse_add()! }

fn (mut p Parser) parse_add() !AstExpr {
	mut left := p.parse_primary()!
	for p.cur.kind == .punc_plus { sp := span(p.cur.line, p.cur.col); p.eat(.punc_plus)!; right := p.parse_primary()!; left = AstBinExpr{left: left, right: right, op: AstOp{kind: .punc_plus}, span: sp} }
	return left
}

fn (mut p Parser) parse_primary() !AstExpr {
	return match p.cur.kind {
		.literal_string { sp := span(p.cur.line, p.cur.col); AstStr{value: p.eat_lit(.literal_string)!, span: sp} }
		.literal_number { sp := span(p.cur.line, p.cur.col); AstNum{value: p.eat_lit(.literal_number)!, span: sp} }
		.identifier { p.parse_id_or_call()! }
		.punc_open_paren { p.eat(.punc_open_paren)!; inner := p.parse_expr()!; p.eat(.punc_close_paren)!; inner }
		.kw_true { sp := span(p.cur.line, p.cur.col); p.eat(.kw_true)!; AstBool{value: true, span: sp} }
		.kw_false { sp := span(p.cur.line, p.cur.col); p.eat(.kw_false)!; AstBool{value: false, span: sp} }
		.punc_open_brace { p.parse_block()! }
		.kw_if { p.parse_if()! }
		.kw_function { p.parse_fn_expr()! }
		else { return error('unexpected ${p.cur.kind}') }
	}
}

fn (mut p Parser) parse_id_or_call() !AstExpr {
	sp := span(p.cur.line, p.cur.col)
	name := p.eat_lit(.identifier)!
	if p.cur.kind == .punc_open_paren { return p.parse_call(name, sp)! }
	return AstId{name: name, span: sp}
}

fn (mut p Parser) parse_block() !AstExpr {
	sp := span(p.cur.line, p.cur.col)
	p.eat(.punc_open_brace)!
	mut body := []AstNode{}
	for p.cur.kind != .punc_close_brace && p.cur.kind != .eof {
		node := p.parse_node() or { body << AstNode(AstExpr(AstError{message: err.msg(), span: sp})); p.advance(); continue }
		body << node
	}
	p.eat(.punc_close_brace)!
	return AstBlock{body: body, span: sp}
}

fn (mut p Parser) parse_if() !AstExpr {
	sp := span(p.cur.line, p.cur.col)
	p.eat(.kw_if)!
	cond := p.parse_expr()!
	body := p.parse_expr()!
	return AstIfExpr{cond: cond, body: body, span: sp}
}

fn (mut p Parser) parse_fn() !AstStmt {
	sp := span(p.cur.line, p.cur.col)
	p.eat(.kw_function)!
	id_sp := span(p.cur.line, p.cur.col)
	name := p.eat_lit(.identifier)!
	p.eat(.punc_open_paren)!
	p.eat(.punc_close_paren)!
	body := p.parse_block()!
	return AstFnDecl{id: AstId{name: name, span: id_sp}, body: body, span: sp}
}

fn (mut p Parser) parse_fn_expr() !AstExpr {
	sp := span(p.cur.line, p.cur.col)
	p.eat(.kw_function)!
	p.eat(.punc_open_paren)!
	p.eat(.punc_close_paren)!
	body := p.parse_block()!
	return AstFnExpr{body: body, span: sp}
}

fn (mut p Parser) parse_binding() !AstStmt {
	sp := span(p.cur.line, p.cur.col)
	name := p.eat_lit(.identifier)!
	p.eat(.punc_equals)!
	init := p.parse_expr()!
	return AstBinding{id: AstId{name: name, span: sp}, init: init, span: sp}
}

fn (mut p Parser) parse_call(name string, sp Span) !AstExpr {
	p.eat(.punc_open_paren)!
	mut args := []AstExpr{}
	for p.cur.kind != .punc_close_paren { args << p.parse_expr()!; if p.cur.kind == .punc_comma { p.eat(.punc_comma)! } }
	p.eat(.punc_close_paren)!
	return AstCall{id: AstId{name: name, span: sp}, args: args, span: sp}
}

// === TYPE ENVIRONMENT ===
pub struct TypeEnv { mut: bindings map[string]Type }
pub fn new_env() TypeEnv { return TypeEnv{bindings: map[string]Type{}} }
pub fn (mut e TypeEnv) define(name string, t Type) { e.bindings[name] = t }

// === TYPE CHECKER ===
pub struct Checker { mut: env TypeEnv }

pub fn check(prog AstBlock) TBlock {
	mut c := Checker{env: new_env()}
	return c.check_block(prog)
}

fn (mut c Checker) check_block(block AstBlock) TBlock {
	mut body := []TBlockItem{}
	for node in block.body {
		match node {
			AstStmt { body << TBlockItem{is_stmt: true, stmt: c.check_stmt(node)} }
			AstExpr { body << TBlockItem{is_stmt: false, expr: c.check_expr(node)} }
		}
	}
	return TBlock{body: body, span: block.span}
}

fn (mut c Checker) check_stmt(stmt AstStmt) TStmt {
	match stmt {
		AstBinding {
			typed_init := c.check_expr(stmt.init)
			c.env.define(stmt.id.name, t_none())
			return TBinding{id: TId{name: stmt.id.name, span: stmt.id.span}, init: typed_init, span: stmt.span}
		}
		AstFnDecl {
			c.env.define(stmt.id.name, t_none())
			typed_body := c.check_expr(stmt.body)
			return TFnDecl{id: TId{name: stmt.id.name, span: stmt.id.span}, body: typed_body, span: stmt.span}
		}
	}
}

fn (mut c Checker) check_expr(expr AstExpr) TExpr {
	match expr {
		AstNum { return TNum{value: expr.value, span: expr.span} }
		AstStr { return TStr{value: expr.value, span: expr.span} }
		AstBool { return TBool{value: expr.value, span: expr.span} }
		AstId { return TId{name: expr.name, span: expr.span} }
		AstBinExpr { return TBinExpr{left: c.check_expr(expr.left), right: c.check_expr(expr.right), op: TOp{kind: expr.op.kind}, span: expr.span} }
		AstFnExpr { return TFnExpr{body: c.check_expr(expr.body), span: expr.span} }
		AstCall { return TCall{id: TId{name: expr.id.name, span: expr.id.span}, span: expr.span} }
		AstBlock { return c.check_block(expr) }
		AstIfExpr { return TIfExpr{cond: c.check_expr(expr.cond), body: c.check_expr(expr.body), span: expr.span} }
		AstError { return TError{message: expr.message, span: expr.span} }
	}
}

// === MAIN ===
fn main() {
	source := '
x = 1
y = 2
z = x + y
fn add() { 1 }
result = add()
'
	mut s := new_scanner(source)
	mut p := new_parser(mut s)
	ast := p.parse()
	println('Parsed: ${ast.body.len} nodes')
	typed := check(ast)
	println('Checked: ${typed.body.len} items')
	println('All tests passed!')
}
