module parser

import scanner
import token
import ast
import diagnostic
import span as sp

pub enum ParseContext {
	top_level
	block
	function_params
	array
}

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
	context_stack         []ParseContext
	prev_token_end_line   int
	prev_token_end_column int
}

pub fn new_parser(mut s scanner.Scanner) Parser {
	return new_parser_from_tokens(s.scan_all(), s.get_diagnostics())
}

pub fn new_parser_from_tokens(tokens []token.Token, scanner_diagnostics []diagnostic.Diagnostic) Parser {
	return Parser{
		tokens:        tokens
		index:         0
		current_token: tokens[0]
		diagnostics:   scanner_diagnostics
		context_stack: [ParseContext.top_level]
	}
}

fn (mut p Parser) push_context(ctx ParseContext) {
	p.context_stack << ctx
}

fn (mut p Parser) pop_context() {
	if p.context_stack.len > 1 {
		p.context_stack.pop()
	}
}

fn (p Parser) current_context() ParseContext {
	if p.context_stack.len > 0 {
		return p.context_stack.last()
	}
	return .top_level
}

fn (mut p Parser) add_error(message string) {
	p.diagnostics << diagnostic.error_at(p.current_token.line, p.current_token.column, message)
}

fn (p Parser) current_span() sp.Span {
	token_len := if lit := p.current_token.literal {
		lit.len
	} else {
		p.current_token.kind.str().len
	}
	return sp.Span{
		start_line:   p.current_token.line
		start_column: p.current_token.column
		end_line:     p.current_token.line
		end_column:   p.current_token.column + token_len
	}
}

fn (p Parser) span_from(start sp.Span) sp.Span {
	return sp.Span{
		start_line:   start.start_line
		start_column: start.start_column
		end_line:     p.prev_token_end_line
		end_column:   p.prev_token_end_column
	}
}

fn (mut p Parser) save_token_end() {
	token_len := if lit := p.current_token.literal {
		lit.len
	} else {
		p.current_token.kind.str().len
	}
	p.prev_token_end_line = p.current_token.line
	p.prev_token_end_column = p.current_token.column + token_len
}

fn (mut p Parser) synchronize() {
	ctx := p.current_context()
	for p.current_token.kind != .eof {
		match ctx {
			.top_level {
				if p.current_token.kind in [.kw_function, .kw_export, .identifier] {
					return
				}
			}
			.block {
				if p.current_token.kind == .punc_close_brace {
					p.advance()
					p.pop_context()
					return
				}
				if p.current_token.kind in [.kw_if, .kw_function, .identifier] {
					return
				}
			}
			.function_params {
				if p.current_token.kind == .punc_close_paren {
					p.advance()
					p.pop_context()
					return
				}
				if p.current_token.kind == .punc_open_brace {
					return
				}
			}
			.array {
				if p.current_token.kind == .punc_close_bracket {
					p.advance()
					p.pop_context()
					return
				}
			}
		}
		p.advance()
	}
}

fn (mut p Parser) advance() {
	if p.index + 1 < p.tokens.len {
		p.save_token_end()
		p.index++
		p.current_token = p.tokens[p.index]
	}
}

fn (mut p Parser) eat(kind token.Kind) !token.Token {
	if p.current_token.kind == kind {
		old := p.current_token
		p.save_token_end()
		p.index = p.index + 1
		p.current_token = p.tokens[p.index]
		return old
	}
	return error("Expected '${kind}', got '${p.current_token}'")
}

fn (mut p Parser) eat_token_literal(kind token.Kind, message string) !string {
	eaten := p.eat(kind) or { return error("${message}, got '${p.current_token}'") }
	if unwrapped := eaten.literal {
		return unwrapped
	}
	return error('Expected ${message}')
}

fn (mut p Parser) peek_next() ?token.Token {
	if p.index + 1 < p.tokens.len {
		return p.tokens[p.index + 1]
	}
	return none
}

pub fn (mut p Parser) parse_program() ParseResult {
	program_span := p.current_span()
	mut body := []ast.Node{}

	for p.current_token.kind != .eof {
		span := p.current_span()
		node := p.parse_node() or {
			p.add_error(err.msg())
			p.synchronize()
			err_expr := ast.Expression(ast.ErrorNode{
				message: err.msg()
				span:    span
			})
			body << ast.Node(err_expr)
			continue
		}
		body << node
	}

	return ParseResult{
		ast:         ast.BlockExpression{
			body: body
			span: p.span_from(program_span)
		}
		diagnostics: p.diagnostics
	}
}

fn (mut p Parser) parse_node() !ast.Node {
	match p.current_token.kind {
		.kw_function {
			return p.parse_function()!
		}
		.kw_export {
			return ast.Node(p.parse_export_declaration()!)
		}
		.identifier {
			if next := p.peek_next() {
				if next.kind == .punc_equals {
					return ast.Node(p.parse_binding()!)
				}
			}
		}
		else {}
	}
	return ast.Node(p.parse_expression()!)
}

fn (mut p Parser) parse_expression() !ast.Expression {
	return p.parse_equality()!
}

fn (mut p Parser) parse_equality() !ast.Expression {
	mut left := p.parse_comparison()!

	for p.current_token.kind in [.punc_equals_comparator, .punc_not_equal] {
		span := p.current_span()
		operator := p.current_token.kind
		p.eat(operator)!
		right := p.parse_comparison()!
		left = ast.BinaryExpression{
			left:  left
			right: right
			op:    ast.Operator{ kind: operator }
			span:  span
		}
	}

	return left
}

fn (mut p Parser) parse_comparison() !ast.Expression {
	mut left := p.parse_additive()!

	for p.current_token.kind in [.punc_lt, .punc_gt, .punc_lte, .punc_gte] {
		span := p.current_span()
		operator := p.current_token.kind
		p.eat(operator)!
		right := p.parse_additive()!
		left = ast.BinaryExpression{
			left:  left
			right: right
			op:    ast.Operator{ kind: operator }
			span:  span
		}
	}

	return left
}

fn (mut p Parser) parse_additive() !ast.Expression {
	mut left := p.parse_multiplicative()!

	for p.current_token.kind in [.punc_plus, .punc_minus] {
		span := p.current_span()
		operator := p.current_token.kind
		p.eat(operator)!
		right := p.parse_multiplicative()!
		left = ast.BinaryExpression{
			left:  left
			right: right
			op:    ast.Operator{ kind: operator }
			span:  span
		}
	}

	return left
}

fn (mut p Parser) parse_multiplicative() !ast.Expression {
	mut left := p.parse_postfix_expression()!

	for p.current_token.kind in [.punc_mul, .punc_div, .punc_mod] {
		span := p.current_span()
		operator := p.current_token.kind
		p.eat(operator)!
		right := p.parse_postfix_expression()!
		left = ast.BinaryExpression{
			left:  left
			right: right
			op:    ast.Operator{ kind: operator }
			span:  span
		}
	}

	return left
}

fn (mut p Parser) parse_postfix_expression() !ast.Expression {
	mut expr := p.parse_primary_expression()!

	for {
		match p.current_token.kind {
			.punc_open_bracket {
				if p.current_token.leading_trivia.len > 0 {
					break
				}
				start := expr.span
				p.eat(.punc_open_bracket)!
				index := p.parse_expression()!
				p.eat(.punc_close_bracket)!
				expr = ast.ArrayIndexExpression{
					expression: expr
					index:      index
					span:       p.span_from(start)
				}
			}
			else {
				break
			}
		}
	}

	return expr
}

fn (mut p Parser) parse_primary_expression() !ast.Expression {
	expr := match p.current_token.kind {
		.literal_string {
			p.parse_string_expression()!
		}
		.literal_number {
			p.parse_number_expression()!
		}
		.identifier {
			p.parse_identifier_or_call()!
		}
		.punc_open_paren {
			p.eat(.punc_open_paren)!
			inner := p.parse_expression()!
			p.eat(.punc_close_paren)!
			inner
		}
		.kw_true {
			span := p.current_span()
			p.eat(.kw_true)!
			ast.BooleanLiteral{ value: true, span: span }
		}
		.kw_false {
			span := p.current_span()
			p.eat(.kw_false)!
			ast.BooleanLiteral{ value: false, span: span }
		}
		.punc_open_brace {
			p.parse_block_expression()!
		}
		.punc_open_bracket {
			p.parse_array_expression()!
		}
		.kw_if {
			p.parse_if_expression()!
		}
		.kw_function {
			p.parse_function_expression()!
		}
		.error {
			span := p.current_span()
			p.advance()
			ast.ErrorNode{ message: 'Scanner error', span: span }
		}
		else {
			return error("Unexpected '${p.current_token}'")
		}
	}

	return expr
}

fn (mut p Parser) parse_identifier_or_call() !ast.Expression {
	span := p.current_span()
	name := p.eat_token_literal(.identifier, 'Expected identifier')!

	if p.current_token.kind == .punc_open_paren {
		return p.parse_function_call_expression(name, span)!
	}

	return ast.Identifier{ name: name, span: span }
}

fn (mut p Parser) parse_block_expression() !ast.Expression {
	block_span := p.current_span()
	p.eat(.punc_open_brace)!
	p.push_context(.block)

	mut body := []ast.Node{}

	for p.current_token.kind != .punc_close_brace && p.current_token.kind != .eof {
		span := p.current_span()
		node := p.parse_node() or {
			p.add_error(err.msg())
			p.synchronize()
			err_expr := ast.Expression(ast.ErrorNode{
				message: err.msg()
				span:    span
			})
			body << ast.Node(err_expr)
			continue
		}
		body << node
	}

	p.pop_context()
	p.eat(.punc_close_brace)!

	return ast.BlockExpression{
		body: body
		span: p.span_from(block_span)
	}
}

fn (mut p Parser) parse_array_expression() !ast.Expression {
	span := p.current_span()
	p.eat(.punc_open_bracket)!
	p.push_context(.array)

	mut elements := []ast.Expression{}

	for p.current_token.kind != .punc_close_bracket && p.current_token.kind != .eof {
		elem_span := p.current_span()
		expr := p.parse_expression() or {
			p.add_error(err.msg())
			p.synchronize()
			if p.current_token.kind == .punc_close_bracket {
				break
			}
			elements << ast.ErrorNode{ message: err.msg(), span: elem_span }
			continue
		}
		elements << expr

		if p.current_token.kind == .punc_comma {
			p.eat(.punc_comma)!
		} else {
			break
		}
	}

	p.pop_context()
	p.eat(.punc_close_bracket)!

	return ast.ArrayExpression{ elements: elements, span: span }
}

fn (mut p Parser) parse_if_expression() !ast.Expression {
	span := p.current_span()
	p.eat(.kw_if)!

	condition := p.parse_expression()!
	body := p.parse_expression()!

	mut else_body := ?ast.Expression(none)

	if p.current_token.kind == .kw_else {
		p.eat(.kw_else)!
		else_body = p.parse_expression()!
	}

	return ast.IfExpression{
		condition: condition
		body:      body
		span:      span
		else_body: else_body
	}
}

fn (mut p Parser) parse_function() !ast.Node {
	if next := p.peek_next() {
		if next.kind == .identifier {
			return ast.Node(p.parse_function_declaration()!)
		}
	}
	return ast.Node(p.parse_function_expression()!)
}

fn (mut p Parser) parse_function_declaration() !ast.Statement {
	fn_span := p.current_span()
	p.eat(.kw_function)!

	id_span := p.current_span()
	name := p.eat_token_literal(.identifier, 'Expected function name')!

	params := p.parse_parameters()!
	body := p.parse_block_expression()!

	return ast.FunctionDeclaration{
		identifier: ast.Identifier{ name: name, span: id_span }
		params:     params
		body:       body
		span:       fn_span
	}
}

fn (mut p Parser) parse_function_expression() !ast.Expression {
	fn_span := p.current_span()
	p.eat(.kw_function)!

	params := p.parse_parameters()!
	body := p.parse_block_expression()!

	return ast.FunctionExpression{
		params: params
		body:   body
		span:   fn_span
	}
}

fn (mut p Parser) parse_parameters() ![]ast.FunctionParameter {
	p.eat(.punc_open_paren)!
	p.push_context(.function_params)

	mut params := []ast.FunctionParameter{}

	for p.current_token.kind != .punc_close_paren && p.current_token.kind != .eof {
		param := p.parse_parameter()!
		params << param

		if p.current_token.kind == .punc_comma {
			p.eat(.punc_comma)!
		}
	}

	p.pop_context()
	p.eat(.punc_close_paren)!

	return params
}

fn (mut p Parser) parse_parameter() !ast.FunctionParameter {
	span := p.current_span()
	name := p.eat_token_literal(.identifier, 'Expected parameter name')!

	return ast.FunctionParameter{
		identifier: ast.Identifier{ name: name, span: span }
	}
}

fn (mut p Parser) parse_binding() !ast.Statement {
	span := p.current_span()
	name := p.eat_token_literal(.identifier, 'Expected identifier')!

	p.eat(.punc_equals)!
	init := p.parse_expression()!

	return ast.VariableBinding{
		identifier: ast.Identifier{ name: name, span: span }
		init:       init
		span:       p.span_from(span)
	}
}

fn (mut p Parser) parse_export_declaration() !ast.Statement {
	span := p.current_span()
	p.eat(.kw_export)!

	decl := match p.current_token.kind {
		.kw_function { p.parse_function_declaration()! }
		.identifier { p.parse_binding()! }
		else { return error('Expected declaration after export') }
	}

	return ast.ExportDeclaration{
		declaration: decl
		span:        span
	}
}

fn (mut p Parser) parse_function_call_expression(name string, name_span sp.Span) !ast.Expression {
	p.eat(.punc_open_paren)!

	mut arguments := []ast.Expression{}

	for p.current_token.kind != .punc_close_paren {
		arguments << p.parse_expression()!

		if p.current_token.kind == .punc_comma {
			p.eat(.punc_comma)!
		}
	}

	p.eat(.punc_close_paren)!

	return ast.FunctionCallExpression{
		identifier: ast.Identifier{ name: name, span: name_span }
		arguments:  arguments
		span:       p.span_from(name_span)
	}
}

fn (mut p Parser) parse_string_expression() !ast.Expression {
	span := p.current_span()
	return ast.StringLiteral{
		value: p.eat_token_literal(.literal_string, 'Expected string')!
		span:  span
	}
}

fn (mut p Parser) parse_number_expression() !ast.Expression {
	span := p.current_span()
	return ast.NumberLiteral{
		value: p.eat_token_literal(.literal_number, 'Expected number')!
		span:  span
	}
}
