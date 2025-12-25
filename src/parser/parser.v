module parser

import scanner
import token
import ast
import diagnostic
import span as sp

pub enum ParseContext { top_level block function_params }

pub struct ParseResult {
pub:
	ast         ast.BlockExpression
	diagnostics []diagnostic.Diagnostic
}

pub struct Parser {
	tokens []token.Token
mut:
	index                 int
	current_token         token.Token
	diagnostics           []diagnostic.Diagnostic
	context_stack         []ParseContext  // kept for struct size
	prev_token_end_line   int             // kept for struct size
	prev_token_end_column int             // kept for struct size
}

pub fn new_parser(mut s scanner.Scanner) Parser {
	tokens := s.scan_all()
	return Parser{
		tokens:        tokens
		current_token: tokens[0]
		diagnostics:   s.get_diagnostics()
	}
}

fn (p Parser) span() sp.Span {
	return sp.Span{start_line: p.current_token.line, start_column: p.current_token.column, end_line: p.current_token.line, end_column: p.current_token.column + 1}
}

fn (mut p Parser) eat(kind token.Kind) !token.Token {
	if p.current_token.kind == kind {
		old := p.current_token
		p.index++
		p.current_token = p.tokens[p.index]
		return old
	}
	return error('unexpected')
}

fn (mut p Parser) eat_lit(kind token.Kind) !string {
	t := p.eat(kind)!
	return t.literal or { '' }
}

pub fn (mut p Parser) parse_program() ParseResult {
	s := p.span()
	mut body := []ast.Node{}
	for p.current_token.kind != .eof {
		if node := p.parse_node() {
			body << node
		} else {
			p.index++
			if p.index < p.tokens.len {
				p.current_token = p.tokens[p.index]
			}
		}
	}
	return ParseResult{ast: ast.BlockExpression{body: body, span: s}, diagnostics: p.diagnostics}
}

fn (mut p Parser) parse_node() !ast.Node {
	if p.current_token.kind == .kw_function {
		if p.index + 1 < p.tokens.len && p.tokens[p.index + 1].kind == .identifier {
			return ast.Node(p.parse_fn_decl()!)
		}
		return ast.Node(p.parse_fn_expr()!)
	}
	if p.current_token.kind == .identifier {
		if p.index + 1 < p.tokens.len && p.tokens[p.index + 1].kind == .punc_equals {
			return ast.Node(p.parse_binding()!)
		}
	}
	return ast.Node(p.parse_expr()!)
}

fn (mut p Parser) parse_expr() !ast.Expression {
	mut left := p.parse_primary()!
	for p.current_token.kind == .punc_plus {
		s := p.span()
		p.eat(.punc_plus)!
		right := p.parse_primary()!
		left = ast.BinaryExpression{left: left, right: right, op: ast.Operator{kind: .punc_plus}, span: s}
	}
	return left
}

fn (mut p Parser) parse_primary() !ast.Expression {
	s := p.span()
	match p.current_token.kind {
		.literal_string { return ast.StringLiteral{value: p.eat_lit(.literal_string)!, span: s} }
		.literal_number { return ast.NumberLiteral{value: p.eat_lit(.literal_number)!, span: s} }
		.identifier {
			name := p.eat_lit(.identifier)!
			if p.current_token.kind == .punc_open_paren {
				return p.parse_call(name, s)!
			}
			return ast.Identifier{name: name, span: s}
		}
		.punc_open_paren {
			p.eat(.punc_open_paren)!
			inner := p.parse_expr()!
			p.eat(.punc_close_paren)!
			return inner
		}
		.kw_true { p.eat(.kw_true)!; return ast.BooleanLiteral{value: true, span: s} }
		.kw_false { p.eat(.kw_false)!; return ast.BooleanLiteral{value: false, span: s} }
		.punc_open_brace { return p.parse_block()! }
		.punc_open_bracket { p.eat(.punc_open_bracket)!; p.eat(.punc_close_bracket)!; return ast.ArrayExpression{span: s} }
		.kw_if { return p.parse_if()! }
		.kw_function { return p.parse_fn_expr()! }
		else { return error('unexpected') }
	}
}

fn (mut p Parser) parse_block() !ast.Expression {
	s := p.span()
	p.eat(.punc_open_brace)!
	mut body := []ast.Node{}
	for p.current_token.kind != .punc_close_brace && p.current_token.kind != .eof {
		if node := p.parse_node() {
			body << node
		} else {
			p.index++
			if p.index < p.tokens.len { p.current_token = p.tokens[p.index] }
		}
	}
	p.eat(.punc_close_brace)!
	return ast.BlockExpression{body: body, span: s}
}

fn (mut p Parser) parse_if() !ast.Expression {
	s := p.span()
	p.eat(.kw_if)!
	cond := p.parse_expr()!
	body := p.parse_expr()!
	mut else_body := ?ast.Expression(none)
	if p.current_token.kind == .kw_else {
		p.eat(.kw_else)!
		else_body = p.parse_expr()!
	}
	return ast.IfExpression{condition: cond, body: body, span: s, else_body: else_body}
}

fn (mut p Parser) parse_fn_decl() !ast.Statement {
	s := p.span()
	p.eat(.kw_function)!
	id_s := p.span()
	name := p.eat_lit(.identifier)!
	params := p.parse_params()!
	ret := p.parse_ret_type()
	body := p.parse_block()!
	return ast.FunctionDeclaration{
		identifier: ast.Identifier{name: name, span: id_s}
		params: params
		return_type: ret
		body: body
		span: s
	}
}

fn (mut p Parser) parse_fn_expr() !ast.Expression {
	s := p.span()
	p.eat(.kw_function)!
	params := p.parse_params()!
	ret := p.parse_ret_type()
	body := p.parse_block()!
	return ast.FunctionExpression{params: params, return_type: ret, body: body, span: s}
}

fn (mut p Parser) parse_ret_type() ?ast.TypeIdentifier {
	if p.current_token.kind == .identifier {
		if name := p.current_token.literal {
			if name.len > 0 && name[0] >= `A` && name[0] <= `Z` {
				s := p.span()
				p.eat(.identifier) or { return none }
				return ast.TypeIdentifier{identifier: ast.Identifier{name: name, span: s}, span: s}
			}
		}
	}
	return none
}

fn (mut p Parser) parse_params() ![]ast.FunctionParameter {
	p.eat(.punc_open_paren)!
	mut params := []ast.FunctionParameter{}
	for p.current_token.kind != .punc_close_paren && p.current_token.kind != .eof {
		s := p.span()
		name := p.eat_lit(.identifier)!
		mut typ := ?ast.TypeIdentifier(none)
		if p.current_token.kind == .identifier {
			if tname := p.current_token.literal {
				if tname.len > 0 && tname[0] >= `A` && tname[0] <= `Z` {
					ts := p.span()
					p.eat(.identifier)!
					typ = ast.TypeIdentifier{identifier: ast.Identifier{name: tname, span: ts}, span: ts}
				}
			}
		}
		params << ast.FunctionParameter{typ: typ, identifier: ast.Identifier{name: name, span: s}}
		if p.current_token.kind == .punc_comma { p.eat(.punc_comma)! }
	}
	p.eat(.punc_close_paren)!
	return params
}

fn (mut p Parser) parse_binding() !ast.Statement {
	s := p.span()
	name := p.eat_lit(.identifier)!
	mut typ := ?ast.TypeIdentifier(none)
	if p.current_token.kind == .identifier {
		if tname := p.current_token.literal {
			if tname.len > 0 && tname[0] >= `A` && tname[0] <= `Z` {
				ts := p.span()
				p.eat(.identifier)!
				typ = ast.TypeIdentifier{identifier: ast.Identifier{name: tname, span: ts}, span: ts}
			}
		}
	}
	p.eat(.punc_equals)!
	init := p.parse_expr()!
	return ast.VariableBinding{identifier: ast.Identifier{name: name, span: s}, typ: typ, init: init, span: s}
}

fn (mut p Parser) parse_call(name string, s sp.Span) !ast.Expression {
	p.eat(.punc_open_paren)!
	mut args := []ast.Expression{}
	for p.current_token.kind != .punc_close_paren {
		args << p.parse_expr()!
		if p.current_token.kind == .punc_comma { p.eat(.punc_comma)! }
	}
	p.eat(.punc_close_paren)!
	return ast.FunctionCallExpression{identifier: ast.Identifier{name: name, span: s}, arguments: args, span: s}
}
