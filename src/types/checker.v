module types

import ast
import typed_ast
import diagnostic
import type_def { Type, t_none }

pub struct TypeChecker {
mut:
	env         TypeEnv
	diagnostics []diagnostic.Diagnostic
}

pub struct CheckResult {
pub:
	success   bool
	typed_ast typed_ast.BlockExpression
}

pub fn check(program ast.BlockExpression) CheckResult {
	mut checker := TypeChecker{
		env:         new_env()
		diagnostics: []diagnostic.Diagnostic{}
	}

	typed_block, _ := checker.check_block(program)

	return CheckResult{
		success:   checker.diagnostics.len == 0
		typed_ast: typed_block
	}
}

fn (mut c TypeChecker) check_block(block ast.BlockExpression) (typed_ast.BlockExpression, Type) {
	mut typed_body := []typed_ast.BlockItem{}

	for node in block.body {
		is_stmt := node is ast.Statement
		if is_stmt {
			stmt := node as ast.Statement
			typed_stmt := c.check_statement(stmt)
			typed_body << typed_ast.BlockItem{
				is_statement: true
				statement:    typed_stmt
			}
		} else {
			expr := node as ast.Expression
			typed_expr := c.check_expr(expr)
			typed_body << typed_ast.BlockItem{
				is_statement: false
				expression:   typed_expr
			}
		}
	}

	return typed_ast.BlockExpression{
		body: typed_body
		span: block.span
	}, t_none()
}

fn (mut c TypeChecker) check_statement(stmt ast.Statement) typed_ast.Statement {
	match stmt {
		ast.VariableBinding {
			typed_init := c.check_expr(stmt.init)
			c.env.define(stmt.identifier.name, t_none())
			return typed_ast.VariableBinding{
				identifier: convert_identifier(stmt.identifier)
				init:       typed_init
				span:       stmt.span
			}
		}
		ast.FunctionDeclaration {
			c.env.define(stmt.identifier.name, t_none())
			for param in stmt.params {
				c.env.define(param.identifier.name, t_none())
			}
			typed_body := c.check_expr(stmt.body)
			return typed_ast.FunctionDeclaration{
				identifier: convert_identifier(stmt.identifier)
				body:       typed_body
				span:       stmt.span
			}
		}
		ast.ExportDeclaration {
			return typed_ast.ExportDeclaration{
				declaration: c.check_statement(stmt.declaration)
				span:        stmt.span
			}
		}
	}
}

fn (mut c TypeChecker) check_expr(expr ast.Expression) typed_ast.Expression {
	match expr {
		ast.NumberLiteral {
			return typed_ast.NumberLiteral{
				value: expr.value
				span:  expr.span
			}
		}
		ast.StringLiteral {
			return typed_ast.StringLiteral{
				value: expr.value
				span:  expr.span
			}
		}
		ast.BooleanLiteral {
			return typed_ast.BooleanLiteral{
				value: expr.value
				span:  expr.span
			}
		}
		ast.Identifier {
			return typed_ast.Identifier{
				name: expr.name
				span: expr.span
			}
		}
		ast.BinaryExpression {
			return typed_ast.BinaryExpression{
				left:  c.check_expr(expr.left)
				right: c.check_expr(expr.right)
				op:    typed_ast.Operator{
					kind: expr.op.kind
				}
				span:  expr.span
			}
		}
		ast.UnaryExpression {
			return typed_ast.UnaryExpression{
				expression: c.check_expr(expr.expression)
				op:         typed_ast.Operator{
					kind: expr.op.kind
				}
				span:       expr.span
			}
		}
		ast.FunctionExpression {
			return typed_ast.FunctionExpression{
				body: c.check_expr(expr.body)
				span: expr.span
			}
		}
		ast.FunctionCallExpression {
			return typed_ast.FunctionCallExpression{
				identifier: convert_identifier(expr.identifier)
				span:       expr.span
			}
		}
		ast.BlockExpression {
			block, _ := c.check_block(expr)
			return block
		}
		ast.IfExpression {
			return typed_ast.IfExpression{
				condition: c.check_expr(expr.condition)
				body:      c.check_expr(expr.body)
				span:      expr.span
			}
		}
		ast.ArrayExpression {
			return typed_ast.ArrayExpression{
				span: expr.span
			}
		}
		ast.PropertyAccessExpression {
			return typed_ast.PropertyAccessExpression{
				left:  c.check_expr(expr.left)
				right: c.check_expr(expr.right)
				span:  expr.span
			}
		}
		ast.ErrorNode {
			return typed_ast.ErrorNode{
				message: expr.message
				span:    expr.span
			}
		}
	}
}

fn convert_identifier(id ast.Identifier) typed_ast.Identifier {
	return typed_ast.Identifier{
		name: id.name
		span: id.span
	}
}
