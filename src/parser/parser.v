module parser

import src.ast
import src.span { Span }

pub struct Parser {
mut:
	pos      int
	tokens   []string
	depth    int
}

pub fn parse(input string) !ast.Expression {
	mut p := Parser{
		pos:    0
		tokens: input.split(' ')
		depth:  0
	}
	return p.parse_expr()
}

fn (mut p Parser) parse_expr() !ast.Expression {
	if p.pos >= p.tokens.len {
		return ast.Expression(ast.NoneExpression{ span: Span{} })
	}

	token := p.tokens[p.pos]
	p.pos++

	match token {
		'block' {
			return p.parse_block()
		}
		'if' {
			return p.parse_if()
		}
		'fn' {
			return p.parse_function()
		}
		'let' {
			return p.parse_let()
		}
		'export' {
			return p.parse_export()
		}
		'match' {
			return p.parse_match()
		}
		else {
			if token.len > 0 && token[0].is_digit() {
				return ast.Expression(ast.NumberLiteral{ value: token, span: Span{} })
			}
			if token.starts_with('"') {
				return ast.Expression(ast.StringLiteral{ value: token.trim('"'), span: Span{} })
			}
			return ast.Expression(ast.Identifier{ name: token, span: Span{} })
		}
	}
}

fn (mut p Parser) parse_block() !ast.Expression {
	p.depth++
	mut items := []ast.BlockItem{}

	for p.pos < p.tokens.len && p.tokens[p.pos] != 'end' {
		if p.tokens[p.pos] == 'let' || p.tokens[p.pos] == 'fn' || p.tokens[p.pos] == 'export' {
			stmt := p.parse_statement()!
			items << ast.BlockItem{
				is_statement: true
				statement:    stmt
			}
		} else {
			expr := p.parse_expr()!
			items << ast.BlockItem{
				is_statement: false
				expression:   expr
			}
		}
	}

	if p.pos < p.tokens.len && p.tokens[p.pos] == 'end' {
		p.pos++
	}

	p.depth--
	return ast.Expression(ast.BlockExpression{
		body: items
		span: Span{}
	})
}

fn (mut p Parser) parse_statement() !ast.Statement {
	token := p.tokens[p.pos]
	p.pos++

	match token {
		'let' {
			name := if p.pos < p.tokens.len {
				n := p.tokens[p.pos]
				p.pos++
				n
			} else {
				'x'
			}

			// skip '='
			if p.pos < p.tokens.len && p.tokens[p.pos] == '=' {
				p.pos++
			}

			init := p.parse_expr()!

			return ast.Statement(ast.VariableBinding{
				identifier: ast.Identifier{ name: name, span: Span{} }
				init:       init
				span:       Span{}
			})
		}
		'fn' {
			name := if p.pos < p.tokens.len {
				n := p.tokens[p.pos]
				p.pos++
				n
			} else {
				'f'
			}

			body := p.parse_expr()!

			return ast.Statement(ast.FunctionDeclaration{
				identifier: ast.Identifier{ name: name, span: Span{} }
				params:     []
				body:       body
				span:       Span{}
			})
		}
		'export' {
			inner := p.parse_statement()!
			return ast.Statement(ast.ExportDeclaration{
				declaration: inner
				span:        Span{}
			})
		}
		else {
			return ast.Statement(ast.VariableBinding{
				identifier: ast.Identifier{ name: 'x', span: Span{} }
				init:       ast.Expression(ast.NoneExpression{ span: Span{} })
				span:       Span{}
			})
		}
	}
}

fn (mut p Parser) parse_if() !ast.Expression {
	condition := p.parse_expr()!

	// skip 'then'
	if p.pos < p.tokens.len && p.tokens[p.pos] == 'then' {
		p.pos++
	}

	body := p.parse_expr()!

	mut else_body := ?ast.Expression(none)
	if p.pos < p.tokens.len && p.tokens[p.pos] == 'else' {
		p.pos++
		else_body = p.parse_expr()!
	}

	return ast.Expression(ast.IfExpression{
		condition: condition
		body:      body
		else_body: else_body
		span:      Span{}
	})
}

fn (mut p Parser) parse_function() !ast.Expression {
	body := p.parse_expr()!
	return ast.Expression(ast.FunctionExpression{
		params: []
		body:   body
		span:   Span{}
	})
}

fn (mut p Parser) parse_let() !ast.Expression {
	// wrap let statement in a block
	stmt := p.parse_statement()!
	return ast.Expression(ast.BlockExpression{
		body: [
			ast.BlockItem{
				is_statement: true
				statement:    stmt
			},
		]
		span: Span{}
	})
}

fn (mut p Parser) parse_export() !ast.Expression {
	stmt := p.parse_statement()!
	return ast.Expression(ast.BlockExpression{
		body: [
			ast.BlockItem{
				is_statement: true
				statement:    stmt
			},
		]
		span: Span{}
	})
}

fn (mut p Parser) parse_match() !ast.Expression {
	subject := p.parse_expr()!
	mut arms := []ast.MatchArm{}

	for p.pos < p.tokens.len && p.tokens[p.pos] != 'end' {
		if p.tokens[p.pos] == 'case' {
			p.pos++
			pattern := p.parse_expr()!
			if p.pos < p.tokens.len && p.tokens[p.pos] == '=>' {
				p.pos++
			}
			body := p.parse_expr()!
			arms << ast.MatchArm{
				pattern: pattern
				body:    body
			}
		} else {
			break
		}
	}

	if p.pos < p.tokens.len && p.tokens[p.pos] == 'end' {
		p.pos++
	}

	return ast.Expression(ast.MatchExpression{
		subject: subject
		arms:    arms
		span:    Span{}
	})
}
