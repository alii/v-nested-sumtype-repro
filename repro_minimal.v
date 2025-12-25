module main

// Testing if large enum triggers the bug

pub struct Span { pub: line int col int }
fn span() Span { return Span{} }

// Large enum from original
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

// === AST (11 variants) ===
pub struct AstNumber { pub: value string span Span }
pub struct AstString { pub: value string span Span }
pub struct AstIdent { pub: name string span Span }
pub struct AstError { pub: msg string span Span }
pub struct AstBool { pub: value bool span Span }
pub struct AstArray { pub: elems []AstExpr span Span }
pub struct AstBinary { pub: left AstExpr right AstExpr span Span }
pub struct AstBlock { pub: items []AstExpr span Span }
pub struct AstIf { pub: cond AstExpr body AstExpr span Span }
pub struct AstFn { pub: body AstExpr span Span }
pub struct AstCall { pub: callee AstExpr span Span }
pub type AstExpr = AstNumber | AstString | AstIdent | AstError | AstBool | AstArray | AstBinary | AstBlock | AstIf | AstFn | AstCall

pub struct AstVarBinding { pub: name AstIdent init AstExpr span Span }
pub struct AstFnDecl { pub: name AstIdent body AstExpr span Span }
pub struct AstExport { pub: decl AstStmt span Span }  // recursive!
pub type AstStmt = AstVarBinding | AstFnDecl | AstExport

pub struct AstProgram { pub: body []AstNode span Span }
pub type AstNode = AstStmt | AstExpr

// === TYPED AST (11 variants) ===
pub struct TNumber { pub: value string span Span }
pub struct TString { pub: value string span Span }
pub struct TIdent { pub: name string span Span }
pub struct TError { pub: msg string span Span }
pub struct TBool { pub: value bool span Span }
pub struct TArray { pub: elems []TExpr span Span }
pub struct TBinary { pub: left TExpr right TExpr span Span }
pub struct TBlock { pub: items []TExpr span Span }
pub struct TIf { pub: cond TExpr body TExpr span Span }
pub struct TFn { pub: body TExpr span Span }
pub struct TCall { pub: callee TExpr span Span }
pub type TExpr = TNumber | TString | TIdent | TError | TBool | TArray | TBinary | TBlock | TIf | TFn | TCall

pub struct TVarBinding { pub: name TIdent init TExpr span Span }
pub struct TFnDecl { pub: name TIdent body TExpr span Span }
pub struct TExport { pub: decl TStmt span Span }
pub type TStmt = TVarBinding | TFnDecl | TExport

pub struct TBlockItem { pub: is_stmt bool stmt TStmt expr TExpr }
pub struct TProgram { pub: body []TBlockItem span Span }

// === Type Environment with map ===
pub type Type = TypeNone
pub struct TypeNone {}
pub fn t_none() Type { return TypeNone{} }

pub struct TypeEnv { mut: bindings map[string]Type }
pub fn new_env() TypeEnv { return TypeEnv{bindings: map[string]Type{}} }
pub fn (mut e TypeEnv) define(name string, t Type) { e.bindings[name] = t }

// === Type Checker ===
pub struct TypeChecker { mut: env TypeEnv }

pub fn check(program AstProgram) TProgram {
	mut c := TypeChecker{env: new_env()}
	return c.check_program(program)
}

fn (mut c TypeChecker) check_program(prog AstProgram) TProgram {
	mut items := []TBlockItem{}
	for node in prog.body {
		match node {
			AstStmt { items << TBlockItem{is_stmt: true, stmt: c.check_stmt(node)} }
			AstExpr { items << TBlockItem{is_stmt: false, expr: c.check_expr(node)} }
		}
	}
	return TProgram{body: items, span: prog.span}
}

fn (mut c TypeChecker) check_stmt(stmt AstStmt) TStmt {
	match stmt {
		AstVarBinding {
			typed_init := c.check_expr(stmt.init)
			c.env.define(stmt.name.name, t_none())  // Map write!
			return TVarBinding{name: TIdent{name: stmt.name.name, span: stmt.name.span}, init: typed_init, span: stmt.span}
		}
		AstFnDecl {
			c.env.define(stmt.name.name, t_none())  // Map write!
			typed_body := c.check_expr(stmt.body)
			return TFnDecl{name: TIdent{name: stmt.name.name, span: stmt.name.span}, body: typed_body, span: stmt.span}
		}
		AstExport { return TExport{decl: c.check_stmt(stmt.decl), span: stmt.span} }
	}
}

fn (mut c TypeChecker) check_expr(expr AstExpr) TExpr {
	match expr {
		AstNumber { return TNumber{value: expr.value, span: expr.span} }
		AstString { return TString{value: expr.value, span: expr.span} }
		AstIdent { return TIdent{name: expr.name, span: expr.span} }
		AstError { return TError{msg: expr.msg, span: expr.span} }
		AstBool { return TBool{value: expr.value, span: expr.span} }
		AstArray { return TArray{span: expr.span} }
		AstBinary { return TBinary{left: c.check_expr(expr.left), right: c.check_expr(expr.right), span: expr.span} }
		AstBlock { return TBlock{span: expr.span} }
		AstIf { return TIf{cond: c.check_expr(expr.cond), body: c.check_expr(expr.body), span: expr.span} }
		AstFn { return TFn{body: c.check_expr(expr.body), span: expr.span} }
		AstCall { return TCall{callee: c.check_expr(expr.callee), span: expr.span} }
	}
}

fn main() {
	program := AstProgram{
		body: [
			AstNode(AstStmt(AstVarBinding{
				name: AstIdent{name: 'x', span: span()}
				init: AstNumber{value: '1', span: span()}
				span: span()
			})),
			AstNode(AstStmt(AstVarBinding{
				name: AstIdent{name: 'y', span: span()}
				init: AstNumber{value: '2', span: span()}
				span: span()
			})),
			AstNode(AstStmt(AstFnDecl{
				name: AstIdent{name: 'add', span: span()}
				body: AstIdent{name: 'x', span: span()}
				span: span()
			})),
		]
		span: span()
	}
	println('AST: ${program.body.len} nodes')
	result := check(program)
	println('Typed: ${result.body.len} items')
	println('All tests passed!')
}
