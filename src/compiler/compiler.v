module compiler

import ast

struct Compiler {
mut:
	result int
}

pub fn compile(expr ast.Expression) int {
	mut c := Compiler{}
	c.compile_expr(expr)
	return c.result
}

fn (mut c Compiler) compile_statement(stmt ast.Statement) {
	match stmt {
		ast.VariableBinding {
			c.compile_expr(stmt.init)
		}
		ast.ConstBinding {
			c.compile_expr(stmt.init)
		}
		ast.TypePatternBinding {
			c.compile_expr(stmt.init)
		}
		ast.FunctionDeclaration {
			c.compile_expr(stmt.body)
		}
		ast.StructDeclaration {}
		ast.EnumDeclaration {}
		ast.ImportDeclaration {}
		ast.ExportDeclaration {
			c.compile_statement(stmt.declaration)
		}
	}
}

fn (mut c Compiler) compile_expr(expr ast.Expression) {
	match expr {
		ast.BlockExpression {
			last_idx := expr.body.len - 1
			for i, item in expr.body {
				is_last := i == last_idx
				if item.is_statement {
					c.compile_statement(item.statement)
				} else {
					c.compile_expr(item.expression)
				}
				// only pop after expressions, not statements
				if !is_last && !item.is_statement {
					c.result += 1
				}
			}

			// push none if block was empty or last item was a statement
			if expr.body.len == 0 {
				c.result += 100
			} else if expr.body[last_idx].is_statement {
				c.result += 100
			}
		}
		ast.NumberLiteral {
			c.result += 1
		}
		ast.StringLiteral {
			c.result += 1
		}
		ast.BooleanLiteral {
			c.result += 1
		}
		ast.NoneExpression {
			c.result += 0
		}
		ast.Identifier {
			c.result += 1
		}
		ast.BinaryExpression {
			c.compile_expr(expr.left)
			c.compile_expr(expr.right)
		}
		ast.UnaryExpression {
			c.compile_expr(expr.expr)
		}
		ast.IfExpression {
			c.compile_expr(expr.condition)
			c.compile_expr(expr.body)
			if e := expr.else_body {
				c.compile_expr(e)
			}
		}
		ast.FunctionExpression {
			c.compile_expr(expr.body)
		}
		ast.FunctionCallExpression {
			for arg in expr.args {
				c.compile_expr(arg)
			}
		}
		ast.ArrayExpression {
			for elem in expr.elements {
				c.compile_expr(elem)
			}
		}
		ast.ArrayIndexExpression {
			c.compile_expr(expr.array)
			c.compile_expr(expr.index)
		}
		ast.PropertyAccessExpression {
			c.compile_expr(expr.left)
			c.compile_expr(expr.right)
		}
		ast.StructInitExpression {
			for field in expr.fields {
				c.compile_expr(field)
			}
		}
		ast.MatchExpression {
			c.compile_expr(expr.subject)
			for arm in expr.arms {
				c.compile_expr(arm)
			}
		}
		ast.OrExpression {
			c.compile_expr(expr.expr)
			c.compile_expr(expr.body)
		}
		ast.ErrorExpression {
			c.compile_expr(expr.expr)
		}
		ast.SpreadExpression {
			if e := expr.expr {
				c.compile_expr(e)
			}
		}
		ast.RangeExpression {
			c.compile_expr(expr.start)
			c.compile_expr(expr.end)
		}
		ast.AssertExpression {
			c.compile_expr(expr.expr)
			c.compile_expr(expr.message)
		}
		ast.InterpolatedString {
			for part in expr.parts {
				c.compile_expr(part)
			}
		}
		ast.ErrorNode {}
		ast.WildcardPattern {}
		ast.OrPattern {
			for p in expr.patterns {
				c.compile_expr(p)
			}
		}
	}
}
