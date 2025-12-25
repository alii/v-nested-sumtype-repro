module main

// Minimal reproduction - testing if variant count matters

pub struct Span { pub: line int col int }
fn span() Span { return Span{} }

// === AST (8 variants) ===
pub struct AstNumber { pub: value string span Span }
pub struct AstString { pub: value string span Span }
pub struct AstIdent { pub: name string span Span }
pub struct AstError { pub: msg string span Span }
pub struct AstBool { pub: value bool span Span }
pub struct AstArray { pub: elems []AstExpr span Span }
pub struct AstBinary { pub: left AstExpr right AstExpr span Span }
pub struct AstBlock { pub: items []AstExpr span Span }
pub type AstExpr = AstNumber | AstString | AstIdent | AstError | AstBool | AstArray | AstBinary | AstBlock

pub struct AstVarBinding { pub: name AstIdent init AstExpr span Span }
pub struct AstFnDecl { pub: name AstIdent body AstExpr span Span }
pub struct AstExport { pub: decl AstStmt span Span }  // recursive!
pub type AstStmt = AstVarBinding | AstFnDecl | AstExport

pub struct AstProgram { pub: body []AstNode span Span }
pub type AstNode = AstStmt | AstExpr

// === TYPED AST (8 variants) ===
pub struct TNumber { pub: value string span Span }
pub struct TString { pub: value string span Span }
pub struct TIdent { pub: name string span Span }
pub struct TError { pub: msg string span Span }
pub struct TBool { pub: value bool span Span }
pub struct TArray { pub: elems []TExpr span Span }
pub struct TBinary { pub: left TExpr right TExpr span Span }
pub struct TBlock { pub: items []TExpr span Span }
pub type TExpr = TNumber | TString | TIdent | TError | TBool | TArray | TBinary | TBlock

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
