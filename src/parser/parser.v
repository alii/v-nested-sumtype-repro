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
	struct_init
	struct_def
	enum_def
	match_arms
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
	p.diagnostics << diagnostic.error_at(p.current_token.line, p.current_token.column,
		message)
}

fn (mut p Parser) add_warning(message string) {
	p.diagnostics << diagnostic.warning_at(p.current_token.line, p.current_token.column,
		message)
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
	mut iterations := 0

	for p.current_token.kind != .eof {
		iterations++
		if iterations > 1000 {
			p.add_error('Parser recovery failed: likely infinite loop detected. This is a bug in the parser.')

			for p.current_token.kind != .eof {
				p.advance()
			}
			return
		}
		match ctx {
			.top_level {
				if p.current_token.kind in [.kw_function, .kw_struct, .kw_enum, .kw_const, .kw_from,
					.kw_export, .identifier] {
					return
				}
			}
			.block {
				if p.current_token.kind == .punc_close_brace {
					p.advance()
					p.pop_context()
					return
				}
				if p.current_token.kind in [.kw_if, .kw_match, .kw_function, .identifier] {
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
				if p.current_token.kind == .punc_comma {
					p.advance()
					return
				}
			}
			.array {
				if p.current_token.kind == .punc_close_bracket {
					p.advance()
					p.pop_context()
					return
				}
				if p.current_token.kind == .punc_comma {
					p.advance()
					return
				}
			}
			.struct_init, .struct_def {
				if p.current_token.kind == .punc_close_brace {
					p.advance()
					p.pop_context()
					return
				}
				if p.current_token.kind == .punc_comma {
					p.advance()
					return
				}
			}
			.enum_def {
				if p.current_token.kind == .punc_close_brace {
					p.advance()
					p.pop_context()
					return
				}
				if p.current_token.kind == .punc_comma {
					p.advance()
					return
				}
			}
			.match_arms {
				if p.current_token.kind == .punc_close_brace {
					p.advance()
					p.pop_context()
					return
				}
				if p.current_token.kind == .punc_arrow {
					return
				}
				if p.current_token.kind == .punc_comma {
					p.advance()
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

fn (mut p Parser) eat_msg(kind token.Kind, message string) !token.Token {
	return p.eat(kind) or { return error("${message}, got '${p.current_token}'") }
}

fn (mut p Parser) eat_token_literal(kind token.Kind, message string) !string {
	eaten := p.eat_msg(kind, message)!

	if unwrapped := eaten.literal {
		return unwrapped
	}

	return error('Expected ${message}')
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
		.identifier {
			if next := p.peek_next() {
				if next.kind == .punc_equals {
					return ast.Node(p.parse_binding()!)
				}
				if p.is_type_start_at_next() {
					return ast.Node(p.parse_binding()!)
				}
			}
		}
		else {}
	}
	return ast.Node(p.parse_expression()!)
}

fn (mut p Parser) peek_next() ?token.Token {
	if p.index + 1 < p.tokens.len {
		return p.tokens[p.index + 1]
	}

	return none
}

fn (mut p Parser) peek_ahead(distance int) ?token.Token {
	if p.index + distance < p.tokens.len {
		return p.tokens[p.index + distance]
	}

	return none
}

fn (mut p Parser) parse_expression() !ast.Expression {
	return p.parse_or_expression()!
}

fn (mut p Parser) parse_or_expression() !ast.Expression {
	mut left := p.parse_binary_expression()!

	if p.current_token.kind == .kw_or {
		p.eat(.kw_or)!

		if p.current_token.kind == .identifier {
			if next := p.peek_next() {
				if next.kind == .punc_arrow {
					_ = p.eat_token_literal(.identifier, 'Expected identifier for or receiver')!
					p.eat(.punc_arrow)!
				}
			}
		}

		_ = p.parse_expression()! // discard body
	}

	return left
}

fn (mut p Parser) parse_binary_expression() !ast.Expression {
	return p.parse_logical_or()!
}

fn (mut p Parser) parse_logical_or() !ast.Expression {
	mut left := p.parse_logical_and()!

	for p.current_token.kind == .logical_or {
		span := p.current_span()
		p.eat(.logical_or)!
		right := p.parse_logical_and()!
		left = ast.BinaryExpression{
			left:  left
			right: right
			op:    ast.Operator{
				kind: .logical_or
			}
			span:  span
		}
	}

	return left
}

fn (mut p Parser) parse_logical_and() !ast.Expression {
	mut left := p.parse_equality()!

	for p.current_token.kind == .logical_and {
		span := p.current_span()
		p.eat(.logical_and)!
		right := p.parse_equality()!
		left = ast.BinaryExpression{
			left:  left
			right: right
			op:    ast.Operator{
				kind: .logical_and
			}
			span:  span
		}
	}

	return left
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
			op:    ast.Operator{
				kind: operator
			}
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
			op:    ast.Operator{
				kind: operator
			}
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
			op:    ast.Operator{
				kind: operator
			}
			span:  span
		}
	}

	return left
}

fn (mut p Parser) parse_multiplicative() !ast.Expression {
	mut left := p.parse_unary_expression()!

	for p.current_token.kind in [.punc_mul, .punc_div, .punc_mod] {
		span := p.current_span()
		operator := p.current_token.kind
		p.eat(operator)!
		right := p.parse_unary_expression()!
		left = ast.BinaryExpression{
			left:  left
			right: right
			op:    ast.Operator{
				kind: operator
			}
			span:  span
		}
	}

	return left
}

fn (mut p Parser) parse_unary_expression() !ast.Expression {
	if p.current_token.kind == .punc_exclamation_mark {
		start := p.current_span()
		p.eat(.punc_exclamation_mark)!
		inner := p.parse_unary_expression()!

		return ast.UnaryExpression{
			expression: inner
			op:         ast.Operator{
				kind: .punc_exclamation_mark
			}
			span:       p.span_from(start)
		}
	}

	if p.current_token.kind == .punc_minus {
		start := p.current_span()
		p.eat(.punc_minus)!
		inner := p.parse_unary_expression()!

		return ast.UnaryExpression{
			expression: inner
			op:         ast.Operator{
				kind: .punc_minus
			}
			span:       p.span_from(start)
		}
	}

	return p.parse_postfix_expression()!
}

fn (mut p Parser) parse_postfix_expression() !ast.Expression {
	mut expr := p.parse_primary_expression()!

	for {
		match p.current_token.kind {
			.punc_dot {
				expr = p.parse_dot_expression(expr)!
			}
			.punc_open_bracket {
				// only treat as array index if there's no whitespace before the bracket
				// this allows `arr[0]` but not `arr [0]` or `x = 1\n[1, 2]`
				if p.current_token.leading_trivia.len > 0 {
					break
				}
				p.eat(.punc_open_bracket)!
				_ = p.parse_expression()! // discard index
				p.eat(.punc_close_bracket)!
				// ArrayIndexExpression removed, keep expr unchanged
			}
			.punc_question_mark {
				p.eat(.punc_question_mark)!
				// PropagateNoneExpression removed, keep expr unchanged
			}
			.punc_dotdot {
				p.eat(.punc_dotdot)!
				_ = p.parse_expression()! // discard end
				// RangeExpression removed, keep expr unchanged
			}
			.punc_plusplus {
				return error('Increment operator (++) is not supported. Values are immutable in AL - use `x = x + 1` with shadowing instead.')
			}
			.punc_minusminus {
				return error('Decrement operator (--) is not supported. Values are immutable in AL - use `x = x - 1` with shadowing instead.')
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
		.literal_string_interpolation {
			p.parse_interpolated_string()!
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
		.kw_none {
			span := p.current_span()
			p.eat(.kw_none)!
			ast.Identifier{
				name: 'none'
				span: span
			}
		}
		.kw_true {
			span := p.current_span()
			p.eat(.kw_true)!
			ast.BooleanLiteral{
				value: true
				span:  span
			}
		}
		.kw_false {
			span := p.current_span()
			p.eat(.kw_false)!
			ast.BooleanLiteral{
				value: false
				span:  span
			}
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
		.kw_match {
			p.parse_match_expression()!
		}
		.kw_function {
			p.parse_function_expression()!
		}
		.kw_assert {
			p.eat(.kw_assert)!
			result := p.parse_expression()!
			p.eat(.punc_comma)!
			_ = p.parse_expression()! // discard message
			result
		}
		.kw_error {
			p.parse_error_expression()!
		}
		.error {
			span := p.current_span()
			p.advance()
			ast.ErrorNode{
				message: 'Scanner error'
				span:    span
			}
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

	if p.current_token.kind == .punc_open_brace {
		curr_index := p.index
		curr_token := p.current_token

		if result := p.parse_struct_init_expression(name, span) {
			return result
		}

		p.index = curr_index
		p.current_token = curr_token
	}

	return ast.Identifier{
		name: name
		span: span
	}
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

		if p.current_token.kind == .punc_dotdot {
			p.eat(.punc_dotdot)!

			// anonymous spread (.. followed by ] or , or else)
			if p.current_token.kind in [.punc_close_bracket, .punc_comma, .kw_else] {
				if p.current_token.kind == .kw_else {
					p.advance() // skip the erroneous 'else' token
				}
				// skip anonymous spread
			} else {
				inner := p.parse_expression() or {
					p.add_error(err.msg())
					p.synchronize()
					if p.current_token.kind == .punc_close_bracket {
						break
					}
					elements << ast.ErrorNode{
						message: err.msg()
						span:    elem_span
					}
					continue
				}
				elements << inner
			}
		} else {
			expr := p.parse_expression() or {
				p.add_error(err.msg())
				p.synchronize()
				if p.current_token.kind == .punc_close_bracket {
					break
				}
				elements << ast.ErrorNode{
					message: err.msg()
					span:    elem_span
				}
				continue
			}
			elements << expr
		}

		if p.current_token.kind == .punc_comma {
			p.eat(.punc_comma)!
		} else {
			break
		}
	}

	p.pop_context()
	p.eat(.punc_close_bracket)!

	return ast.ArrayExpression{
		elements: elements
		span:     span
	}
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

fn (mut p Parser) parse_match_expression() !ast.Expression {
	p.eat(.kw_match)!

	subject := p.parse_expression()!

	p.eat(.punc_open_brace)!
	p.push_context(.match_arms)

	// Parse and discard match arms since MatchExpression is removed
	for p.current_token.kind != .punc_close_brace && p.current_token.kind != .eof {
		if p.current_token.kind == .kw_else {
			p.eat(.kw_else)!
		} else {
			_ = p.parse_expression() or {
				p.add_error(err.msg())
				p.synchronize()
				if p.current_token.kind == .punc_close_brace {
					break
				}
				continue
			}
		}

		for p.current_token.kind == .bitwise_or {
			p.eat(.bitwise_or)!
			_ = p.parse_expression() or {
				p.add_error(err.msg())
				p.synchronize()
				break
			}
		}

		p.eat(.punc_arrow) or {
			p.add_error(err.msg())
			p.synchronize()
			if p.current_token.kind == .punc_close_brace {
				break
			}
			continue
		}

		_ = p.parse_expression() or {
			p.add_error(err.msg())
			p.synchronize()
			if p.current_token.kind == .punc_close_brace {
				break
			}
			continue
		}

		if p.current_token.kind == .punc_comma {
			p.eat(.punc_comma)!
		}
	}

	p.pop_context()
	p.eat(.punc_close_brace)!

	return subject
}

fn (mut p Parser) parse_function() !ast.Node {
	// Check if next token is identifier (declaration) or paren (expression)
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
	return_type, error_type := p.parse_function_return_types()!
	body := p.parse_block_expression()!

	return ast.FunctionDeclaration{
		identifier:  ast.Identifier{
			name: name
			span: id_span
		}
		params:      params
		return_type: return_type
		error_type:  error_type
		body:        body
		span:        fn_span
	}
}

fn (mut p Parser) parse_function_expression() !ast.Expression {
	fn_span := p.current_span()
	p.eat(.kw_function)!

	params := p.parse_parameters()!
	return_type, error_type := p.parse_function_return_types()!
	body := p.parse_block_expression()!

	return ast.FunctionExpression{
		params:      params
		return_type: return_type
		error_type:  error_type
		body:        body
		span:        fn_span
	}
}

fn (mut p Parser) parse_function_return_types() !(?ast.TypeIdentifier, ?ast.TypeIdentifier) {
	mut return_type := ?ast.TypeIdentifier(none)
	mut error_type := ?ast.TypeIdentifier(none)

	if p.current_token.kind == .punc_question_mark {
		span := p.current_span()
		p.eat(.punc_question_mark)!
		if p.current_token.kind == .punc_open_brace {
			return_type = ast.TypeIdentifier{
				is_option:  true
				identifier: ast.Identifier{
					name: 'None'
					span: span
				}
				span:       span
			}
		} else {
			inner := p.parse_type_identifier()!
			return_type = ast.TypeIdentifier{
				is_option:   true
				is_array:    inner.is_array
				is_function: inner.is_function
				identifier:  inner.identifier
				param_types: inner.param_types
				return_type: inner.return_type
				error_type:  inner.error_type
				span:        inner.span
			}
		}
	} else if p.current_token.kind == .identifier || p.current_token.kind == .punc_open_bracket {
		return_type = p.parse_type_identifier()!
	}

	if p.current_token.kind == .punc_exclamation_mark {
		p.eat(.punc_exclamation_mark)!
		error_type = p.parse_type_identifier()!
	}

	return return_type, error_type
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

	mut typ := ?ast.TypeIdentifier(none)

	if p.current_token.kind == .identifier || p.current_token.kind == .punc_open_bracket
		|| p.current_token.kind == .punc_question_mark || p.current_token.kind == .kw_function {
		typ = p.parse_type_identifier()!
	}

	return ast.FunctionParameter{
		typ:        typ
		identifier: ast.Identifier{
			name: name
			span: span
		}
	}
}

fn (mut p Parser) is_type_start() bool {
	if p.current_token.kind == .punc_question_mark {
		return true
	}

	if p.current_token.kind == .punc_open_bracket {
		if next := p.peek_next() {
			return next.kind == .punc_close_bracket
		}
		return false
	}

	if p.current_token.kind == .identifier {
		if name := p.current_token.literal {
			return name.len > 0 && name[0] >= `A` && name[0] <= `Z`
		}
	}

	return false
}

fn (mut p Parser) is_type_start_at_next() bool {
	next := p.peek_next() or { return false }

	if next.kind == .punc_question_mark {
		return true
	}

	if next.kind == .punc_open_bracket {
		return true
	}

	if next.kind == .identifier {
		if name := next.literal {
			return name.len > 0 && name[0] >= `A` && name[0] <= `Z`
		}
	}

	return false
}

fn (mut p Parser) parse_type_identifier() !ast.TypeIdentifier {
	mut is_option := false

	if p.current_token.kind == .punc_question_mark {
		is_option = true
		p.eat(.punc_question_mark)!
	}

	// Array type: []T where T can itself be an array type
	if p.current_token.kind == .punc_open_bracket {
		start_span := p.current_span()
		p.eat(.punc_open_bracket)!
		p.eat(.punc_close_bracket)!
		inner := p.parse_type_identifier()!
		return ast.TypeIdentifier{
			is_option:    is_option
			is_array:     true
			element_type: &inner
			identifier:   ast.Identifier{
				span: start_span
			}
			span:         p.span_from(start_span)
		}
	}

	if p.current_token.kind == .kw_function {
		return p.parse_function_type(is_option)!
	}

	span := p.current_span()
	name := p.eat_token_literal(.identifier, 'Expected type name')!

	return ast.TypeIdentifier{
		is_option:  is_option
		is_array:   false
		identifier: ast.Identifier{
			name: name
			span: span
		}
		span:       span
	}
}

fn (mut p Parser) parse_function_type(is_option bool) !ast.TypeIdentifier {
	span := p.current_span()
	p.eat(.kw_function)!
	p.eat(.punc_open_paren)!

	mut param_types := []ast.TypeIdentifier{}

	for p.current_token.kind != .punc_close_paren && p.current_token.kind != .eof {
		param_type := p.parse_type_identifier()!
		param_types << param_type

		if p.current_token.kind == .punc_comma {
			p.eat(.punc_comma)!
		}
	}

	p.eat(.punc_close_paren)!

	mut return_type := ?&ast.TypeIdentifier(none)
	mut error_type := ?&ast.TypeIdentifier(none)

	if p.current_token.kind == .identifier || p.current_token.kind == .punc_open_bracket
		|| p.current_token.kind == .punc_question_mark || p.current_token.kind == .kw_function {
		mut ret := p.parse_type_identifier()!
		return_type = &ret

		if p.current_token.kind == .punc_exclamation_mark {
			p.eat(.punc_exclamation_mark)!
			mut err := p.parse_type_identifier()!
			error_type = &err
		}
	}

	return ast.TypeIdentifier{
		is_option:   is_option
		is_function: true
		identifier:  ast.Identifier{
			name: 'fn'
			span: span
		}
		param_types: param_types
		return_type: return_type
		error_type:  error_type
		span:        p.span_from(span)
	}
}

fn (mut p Parser) parse_struct_declaration() !ast.Statement {
	struct_span := p.current_span()
	p.eat(.kw_struct)!

	id_span := p.current_span()
	name := p.eat_token_literal(.identifier, 'Expected struct name')!

	p.eat(.punc_open_brace)!
	p.push_context(.struct_def)

	// Parse and discard fields since StructDeclaration is removed
	for p.current_token.kind != .punc_close_brace && p.current_token.kind != .eof {
		p.parse_struct_field()!
	}

	p.pop_context()
	p.eat(.punc_close_brace)!

	// Return a dummy VariableBinding since StructDeclaration is removed
	return ast.VariableBinding{
		identifier: ast.Identifier{
			name: name
			span: id_span
		}
		init: ast.NumberLiteral{
			value: '0'
			span:  struct_span
		}
		span: p.span_from(struct_span)
	}
}

fn (mut p Parser) parse_struct_field() ! {
	_ = p.eat_token_literal(.identifier, 'Expected field name')!
	_ = p.parse_type_identifier()!

	if p.current_token.kind == .punc_equals {
		p.eat(.punc_equals)!
		_ = p.parse_expression()!
	}

	if p.current_token.kind == .punc_comma {
		p.eat(.punc_comma)!
	}
}

fn (mut p Parser) parse_enum_declaration() !ast.Statement {
	enum_span := p.current_span()
	p.eat(.kw_enum)!

	id_span := p.current_span()
	name := p.eat_token_literal(.identifier, 'Expected enum name')!

	p.eat(.punc_open_brace)!
	p.push_context(.enum_def)

	// Parse and discard variants since EnumDeclaration is removed
	for p.current_token.kind != .punc_close_brace && p.current_token.kind != .eof {
		p.parse_enum_variant()!
	}

	p.pop_context()
	p.eat(.punc_close_brace)!

	// Return a dummy VariableBinding since EnumDeclaration is removed
	return ast.VariableBinding{
		identifier: ast.Identifier{
			name: name
			span: id_span
		}
		init: ast.NumberLiteral{
			value: '0'
			span:  enum_span
		}
		span: p.span_from(enum_span)
	}
}

fn (mut p Parser) parse_enum_variant() ! {
	_ = p.eat_token_literal(.identifier, 'Expected variant name')!

	if p.current_token.kind == .punc_open_paren {
		p.eat(.punc_open_paren)!
		for p.current_token.kind != .punc_close_paren {
			_ = p.parse_type_identifier()!
			if p.current_token.kind == .punc_comma {
				p.eat(.punc_comma)!
			} else {
				break
			}
		}
		p.eat(.punc_close_paren)!
	}

	if p.current_token.kind == .punc_comma {
		p.eat(.punc_comma)!
	}
}

fn (mut p Parser) parse_struct_init_expression(name string, name_span sp.Span) !ast.Expression {
	p.eat(.punc_open_brace)!
	p.push_context(.struct_init)

	// Parse and discard fields since StructInitExpression is removed
	for p.current_token.kind != .punc_close_brace && p.current_token.kind != .eof {
		_ = p.eat_token_literal(.identifier, 'Expected field name')!
		p.eat(.punc_colon)!
		_ = p.parse_expression()!

		if p.current_token.kind == .punc_comma {
			p.eat(.punc_comma)!
		}
	}

	p.pop_context()
	p.eat(.punc_close_brace)!

	// Return just an Identifier since StructInitExpression is removed
	return ast.Identifier{
		name: name
		span: name_span
	}
}

fn (mut p Parser) parse_binding() !ast.Statement {
	span := p.current_span()
	name := p.eat_token_literal(.identifier, 'Expected identifier')!

	// Check for type annotation
	mut typ := ?ast.TypeIdentifier(none)
	if p.is_type_start() {
		typ = p.parse_type_identifier()!
	}

	p.eat(.punc_equals)!
	init := p.parse_expression()!

	return ast.VariableBinding{
		identifier: ast.Identifier{
			name: name
			span: span
		}
		typ:        typ
		init:       init
		span:       p.span_from(span)
	}
}

fn (mut p Parser) parse_import_declaration() !ast.Statement {
	import_span := p.current_span()
	p.eat(.kw_from)!

	path_token := p.eat(.literal_string)!
	_ = path_token.literal or { return error('Expected string literal for import path') }

	p.eat(.kw_import)!

	p.parse_import_specifiers()!

	// Return a dummy VariableBinding since ImportDeclaration is not in Statement sum type
	return ast.VariableBinding{
		identifier: ast.Identifier{
			name: '_import'
			span: import_span
		}
		init: ast.NumberLiteral{
			value: '0'
			span:  import_span
		}
		span: import_span
	}
}

fn (mut p Parser) parse_import_specifiers() ! {
	_ = p.eat_token_literal(.identifier, 'Expected import specifier')!

	if p.current_token.kind == .punc_comma {
		p.eat(.punc_comma)!
		p.parse_import_specifiers()!
	}
}

fn (mut p Parser) parse_assert_expression() !ast.Expression {
	p.eat(.kw_assert)!

	expr := p.parse_expression()!

	p.eat(.punc_comma)!

	_ = p.parse_expression()!

	return expr
}

fn (mut p Parser) parse_error_expression() !ast.Expression {
	p.eat(.kw_error)!

	expr := p.parse_unary_expression()!

	return expr
}

fn (mut p Parser) parse_dot_expression(left ast.Expression) !ast.Expression {
	start := left.span
	p.eat(.punc_dot)!

	span := p.current_span()
	property := p.eat_token_literal(.identifier, 'Expected property name')!

	if p.current_token.kind == .punc_open_paren {
		call := p.parse_function_call_expression(property, span)!
		return ast.PropertyAccessExpression{
			left:  left
			right: call
			span:  p.span_from(start)
		}
	}

	return ast.PropertyAccessExpression{
		left:  left
		right: ast.Identifier{
			name: property
			span: span
		}
		span:  p.span_from(start)
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
		identifier: ast.Identifier{
			name: name
			span: name_span
		}
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

fn (mut p Parser) parse_interpolated_string() !ast.Expression {
	span := p.current_span()
	raw := p.eat_token_literal(.literal_string_interpolation, 'Expected interpolated string')!

	mut parts := []ast.Expression{}
	mut current := ''
	mut i := 0

	for i < raw.len {
		ch := raw[i]

		if ch == `$` {
			if current.len > 0 {
				parts << ast.StringLiteral{
					value: current
					span:  span
				}
				current = ''
			}

			i++
			if i >= raw.len {
				return error('Unexpected end of interpolated string after $')
			}

			if raw[i] == `{` {
				i++
				mut expr_str := ''
				mut brace_depth := 1
				for i < raw.len && brace_depth > 0 {
					if raw[i] == `{` {
						brace_depth++
					} else if raw[i] == `}` {
						brace_depth--
						if brace_depth == 0 {
							break
						}
					}
					expr_str += raw[i].ascii_str()
					i++
				}
				if brace_depth != 0 {
					return error('Unclosed { in interpolated string')
				}
				i++

				mut s := scanner.new_scanner(expr_str)
				mut expr_parser := new_parser(mut s)
				expr := expr_parser.parse_expression()!
				parts << expr
			} else {
				mut ident := ''
				for i < raw.len
					&& (raw[i].is_letter() || raw[i] == `_` || (ident.len > 0 && raw[i].is_digit())) {
					ident += raw[i].ascii_str()
					i++
				}
				if ident.len == 0 {
					return error('Expected identifier after $ in interpolated string')
				}
				parts << ast.Identifier{
					name: ident
					span: span
				}
			}
		} else {
			current += ch.ascii_str()
			i++
		}
	}

	if current.len > 0 {
		parts << ast.StringLiteral{
			value: current
			span:  span
		}
	}

	// Return first part or just the string if no interpolation
	if parts.len > 0 {
		return parts[0]
	}
	return ast.StringLiteral{
		value: raw
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
