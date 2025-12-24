module compiler

import src.ast
import src.type_def

struct Compiler {
mut:
	count       int
	local_count int
	in_tail     bool
	depth       int
}

pub fn compile(expr ast.Expression) int {
	mut c := Compiler{
		count:       0
		local_count: 0
		in_tail:     false
		depth:       0
	}
	c.compile_expr(expr)
	return c.count
}

fn (mut c Compiler) compile_statement(stmt ast.Statement) {
	match stmt {
		ast.VariableBinding {
			c.count += 1
			c.compile_expr(stmt.init)
		}
		ast.ConstBinding {
			c.count += 1
			c.compile_expr(stmt.init)
		}
		ast.TypePatternBinding {
			c.count += 1
			c.compile_expr(stmt.init)
		}
		ast.FunctionDeclaration {
			c.count += 1
			c.compile_expr(stmt.body)
		}
		ast.StructDeclaration {
			c.count += 1
		}
		ast.EnumDeclaration {
			c.count += 1
		}
		ast.ImportDeclaration {
			c.count += 1
		}
		ast.ExportDeclaration {
			c.count += 1
			c.compile_statement(stmt.declaration)
		}
	}
}

fn (mut c Compiler) compile_expr(expr ast.Expression) {
	is_tail := c.in_tail
	c.in_tail = false

	match expr {
		ast.BlockExpression {
			last_idx := expr.body.len - 1
			for i, item in expr.body {
				is_last := i == last_idx
				c.in_tail = is_tail && is_last
				if item.is_statement {
					c.compile_statement(item.statement)
				} else {
					c.compile_expr(item.expression)
				}
				c.in_tail = false
				if !is_last && !item.is_statement {
					c.count += 1
				}
			}
			if expr.body.len == 0 {
				c.count += 1
			} else if expr.body[last_idx].is_statement {
				c.count += 1
			}
		}
		ast.NumberLiteral {
			c.count += 1
		}
		ast.StringLiteral {
			c.count += 1
		}
		ast.InterpolatedString {
			for part in expr.parts {
				c.compile_expr(part)
			}
			c.count += 1
		}
		ast.BooleanLiteral {
			c.count += 1
		}
		ast.NoneExpression {
			c.count += 1
		}
		ast.Identifier {
			c.count += 1
		}
		ast.BinaryExpression {
			c.compile_expr(expr.left)
			c.compile_expr(expr.right)
			c.count += 1
		}
		ast.UnaryExpression {
			c.compile_expr(expr.expression)
			c.count += 1
		}
		ast.IfExpression {
			c.compile_expr(expr.condition)
			c.in_tail = is_tail
			c.compile_expr(expr.body)
			c.in_tail = false
			c.in_tail = is_tail
			if else_body := expr.else_body {
				c.compile_expr(else_body)
			} else {
				c.count += 1
			}
			c.in_tail = false
		}
		ast.MatchExpression {
			c.compile_expr(expr.subject)
			for arm in expr.arms {
				c.compile_expr(arm.pattern)
				c.in_tail = is_tail
				c.compile_expr(arm.body)
				c.in_tail = false
			}
			c.count += 1
		}
		ast.ArrayExpression {
			for elem in expr.elements {
				c.compile_expr(elem)
			}
			c.count += 1
		}
		ast.ArrayIndexExpression {
			c.compile_expr(expr.expression)
			c.compile_expr(expr.index)
			c.count += 1
		}
		ast.RangeExpression {
			c.compile_expr(expr.start)
			c.compile_expr(expr.end)
			c.count += 1
		}
		ast.SpreadExpression {
			if inner := expr.expression {
				c.compile_expr(inner)
			}
			c.count += 1
		}
		ast.FunctionExpression {
			c.depth += 1
			old_tail := c.in_tail
			c.in_tail = true
			c.compile_expr(expr.body)
			c.in_tail = old_tail
			c.depth -= 1
			c.count += 1
		}
		ast.FunctionCallExpression {
			for arg in expr.arguments {
				c.compile_expr(arg)
			}
			c.count += 1
		}
		ast.PropertyAccessExpression {
			c.compile_expr(expr.left)
			c.compile_expr(expr.right)
			c.count += 1
		}
		ast.StructInitExpression {
			for field in expr.fields {
				c.compile_expr(field.init)
			}
			c.count += 1
		}
		ast.AssertExpression {
			c.compile_expr(expr.expression)
			c.compile_expr(expr.message)
			c.count += 1
		}
		ast.ErrorExpression {
			c.compile_expr(expr.expression)
			c.count += 1
		}
		ast.OrExpression {
			c.compile_expr(expr.expression)
			resolved := expr.resolved_type
			if resolved is type_def.TypeResult {
				c.compile_expr(expr.body)
			} else if resolved is type_def.TypeOption {
				c.compile_expr(expr.body)
			}
			c.count += 1
		}
		ast.PropagateNoneExpression {
			c.compile_expr(expr.expression)
			resolved := expr.resolved_type
			if resolved is type_def.TypeOption {
				c.count += 1
			}
		}
		ast.WildcardPattern {
			c.count += 1
		}
		ast.OrPattern {
			for pattern in expr.patterns {
				c.compile_expr(pattern)
			}
			c.count += 1
		}
		ast.ErrorNode {
			c.count += 1
		}
		ast.TypeIdentifier {
			c.count += 1
		}
	}
}
