module types

import ast
import typed_ast
import diagnostic
import type_def { Type, t_none }

pub struct CheckResult {
pub:
	diagnostics []diagnostic.Diagnostic
	success     bool
	typed_ast   typed_ast.BlockExpression
}

pub fn check(program ast.BlockExpression) CheckResult {
	typed_block := check_block(program)
	return CheckResult{
		diagnostics: []
		success:     true
		typed_ast:   typed_block
	}
}

fn check_block(block ast.BlockExpression) typed_ast.BlockExpression {
	mut items := []typed_ast.BlockItem{}
	for node in block.body {
		match node {
			ast.Statement {
				items << typed_ast.BlockItem{
					is_statement: true
					statement:    check_statement(node)
					expression:   typed_ast.Expression(typed_ast.NoneExpression{ span: block.span })
				}
			}
			ast.Expression {
				items << typed_ast.BlockItem{
					is_statement: false
					statement:    typed_ast.Statement(typed_ast.VariableBinding{
						identifier: typed_ast.Identifier{ name: '', span: block.span }
						init:       typed_ast.Expression(typed_ast.NoneExpression{ span: block.span })
						span:       block.span
					})
					expression:   check_expr(node)
				}
			}
		}
	}
	return typed_ast.BlockExpression{
		body: items
		span: block.span
	}
}

fn check_statement(stmt ast.Statement) typed_ast.Statement {
	return match stmt {
		ast.VariableBinding {
			typed_ast.Statement(typed_ast.VariableBinding{
				identifier: typed_ast.Identifier{ name: stmt.identifier.name, span: stmt.identifier.span }
				init:       check_expr(stmt.init)
				span:       stmt.span
			})
		}
		ast.ConstBinding {
			typed_ast.Statement(typed_ast.ConstBinding{
				identifier: typed_ast.Identifier{ name: stmt.identifier.name, span: stmt.identifier.span }
				init:       check_expr(stmt.init)
				span:       stmt.span
			})
		}
		ast.FunctionDeclaration {
			typed_ast.Statement(typed_ast.FunctionDeclaration{
				identifier: typed_ast.Identifier{ name: stmt.identifier.name, span: stmt.identifier.span }
				params:     []
				body:       check_expr(stmt.body)
				span:       stmt.span
			})
		}
		ast.StructDeclaration {
			typed_ast.Statement(typed_ast.StructDeclaration{
				identifier: typed_ast.Identifier{ name: stmt.identifier.name, span: stmt.identifier.span }
				fields:     []
				span:       stmt.span
			})
		}
		ast.EnumDeclaration {
			typed_ast.Statement(typed_ast.EnumDeclaration{
				identifier: typed_ast.Identifier{ name: stmt.identifier.name, span: stmt.identifier.span }
				variants:   []
				span:       stmt.span
			})
		}
		ast.ImportDeclaration {
			typed_ast.Statement(typed_ast.ImportDeclaration{
				path: stmt.path
				span: stmt.span
			})
		}
		ast.TypePatternBinding {
			typed_ast.Statement(typed_ast.TypePatternBinding{
				typ:  typed_ast.TypeIdentifier{
					identifier: typed_ast.Identifier{ name: '', span: stmt.span }
					span:       stmt.span
				}
				init: check_expr(stmt.init)
				span: stmt.span
			})
		}
		ast.ExportDeclaration {
			typed_ast.Statement(typed_ast.ExportDeclaration{
				declaration: check_statement(stmt.declaration)
				span:        stmt.span
			})
		}
	}
}

fn check_expr(expr ast.Expression) typed_ast.Expression {
	return match expr {
		ast.NumberLiteral {
			typed_ast.Expression(typed_ast.NumberLiteral{ value: expr.value, span: expr.span })
		}
		ast.StringLiteral {
			typed_ast.Expression(typed_ast.StringLiteral{ value: expr.value, span: expr.span })
		}
		ast.BooleanLiteral {
			typed_ast.Expression(typed_ast.BooleanLiteral{ value: expr.value, span: expr.span })
		}
		ast.Identifier {
			typed_ast.Expression(typed_ast.Identifier{ name: expr.name, span: expr.span })
		}
		ast.BinaryExpression {
			typed_ast.Expression(typed_ast.BinaryExpression{
				left:  check_expr(expr.left)
				right: check_expr(expr.right)
				op:    typed_ast.Operator{ kind: expr.op.kind }
				span:  expr.span
			})
		}
		ast.UnaryExpression {
			typed_ast.Expression(typed_ast.UnaryExpression{
				expression: check_expr(expr.expression)
				op:         typed_ast.Operator{ kind: expr.op.kind }
				span:       expr.span
			})
		}
		ast.IfExpression {
			mut else_body := ?typed_ast.Expression(none)
			if eb := expr.else_body {
				else_body = check_expr(eb)
			}
			typed_ast.Expression(typed_ast.IfExpression{
				condition: check_expr(expr.condition)
				body:      check_expr(expr.body)
				else_body: else_body
				span:      expr.span
			})
		}
		ast.MatchExpression {
			mut arms := []typed_ast.MatchArm{}
			for arm in expr.arms {
				arms << typed_ast.MatchArm{
					pattern: check_expr(arm.pattern)
					body:    check_expr(arm.body)
				}
			}
			typed_ast.Expression(typed_ast.MatchExpression{
				subject: check_expr(expr.subject)
				arms:    arms
				span:    expr.span
			})
		}
		ast.FunctionExpression {
			typed_ast.Expression(typed_ast.FunctionExpression{
				params: []
				body:   check_expr(expr.body)
				span:   expr.span
			})
		}
		ast.FunctionCallExpression {
			mut args := []typed_ast.Expression{}
			for arg in expr.arguments {
				args << check_expr(arg)
			}
			typed_ast.Expression(typed_ast.FunctionCallExpression{
				identifier: typed_ast.Identifier{ name: expr.identifier.name, span: expr.identifier.span }
				arguments:  args
				span:       expr.span
			})
		}
		ast.ArrayExpression {
			mut elems := []typed_ast.Expression{}
			for e in expr.elements {
				elems << check_expr(e)
			}
			typed_ast.Expression(typed_ast.ArrayExpression{
				elements: elems
				span:     expr.span
			})
		}
		ast.ArrayIndexExpression {
			typed_ast.Expression(typed_ast.ArrayIndexExpression{
				expression: check_expr(expr.expression)
				index:      check_expr(expr.index)
				span:       expr.span
			})
		}
		ast.RangeExpression {
			typed_ast.Expression(typed_ast.RangeExpression{
				start: check_expr(expr.start)
				end:   check_expr(expr.end)
				span:  expr.span
			})
		}
		ast.PropertyAccessExpression {
			typed_ast.Expression(typed_ast.PropertyAccessExpression{
				left:  check_expr(expr.left)
				right: check_expr(expr.right)
				span:  expr.span
			})
		}
		ast.StructInitExpression {
			typed_ast.Expression(typed_ast.StructInitExpression{
				identifier: typed_ast.Identifier{ name: expr.identifier.name, span: expr.identifier.span }
				fields:     []
				span:       expr.span
			})
		}
		ast.NoneExpression {
			typed_ast.Expression(typed_ast.NoneExpression{ span: expr.span })
		}
		ast.ErrorNode {
			typed_ast.Expression(typed_ast.ErrorNode{ message: expr.message, span: expr.span })
		}
		ast.ErrorExpression {
			typed_ast.Expression(typed_ast.ErrorExpression{
				expression: check_expr(expr.expression)
				span:       expr.span
			})
		}
		ast.OrExpression {
			typed_ast.Expression(typed_ast.OrExpression{
				expression:    check_expr(expr.expression)
				body:          check_expr(expr.body)
				resolved_type: t_none()
				span:          expr.span
			})
		}
		ast.PropagateNoneExpression {
			typed_ast.Expression(typed_ast.PropagateNoneExpression{
				expression:    check_expr(expr.expression)
				resolved_type: t_none()
				span:          expr.span
			})
		}
		ast.InterpolatedString {
			mut parts := []typed_ast.Expression{}
			for p in expr.parts {
				parts << check_expr(p)
			}
			typed_ast.Expression(typed_ast.InterpolatedString{
				parts: parts
				span:  expr.span
			})
		}
		ast.TypeIdentifier {
			typed_ast.Expression(typed_ast.TypeIdentifier{
				identifier: typed_ast.Identifier{ name: expr.identifier.name, span: expr.identifier.span }
				span:       expr.span
			})
		}
		ast.AssertExpression {
			typed_ast.Expression(typed_ast.AssertExpression{
				expression: check_expr(expr.expression)
				message:    check_expr(expr.message)
				span:       expr.span
			})
		}
		ast.WildcardPattern {
			typed_ast.Expression(typed_ast.WildcardPattern{ span: expr.span })
		}
		ast.OrPattern {
			mut patterns := []typed_ast.Expression{}
			for p in expr.patterns {
				patterns << check_expr(p)
			}
			typed_ast.Expression(typed_ast.OrPattern{
				patterns: patterns
				span:     expr.span
			})
		}
		ast.SpreadExpression {
			mut inner := ?typed_ast.Expression(none)
			if e := expr.expression {
				inner = check_expr(e)
			}
			typed_ast.Expression(typed_ast.SpreadExpression{
				expression: inner
				span:       expr.span
			})
		}
		ast.BlockExpression {
			typed_ast.Expression(check_block(expr))
		}
	}
}
