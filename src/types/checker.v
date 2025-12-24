module types

import ast
import typed_ast
import diagnostic
import type_def {
	Type,
	TypeFunction,
	t_bool,
	t_float,
	t_int,
	t_none,
	t_string,
	t_array,
}

pub struct TypeChecker {
mut:
	env         TypeEnv
	diagnostics []diagnostic.Diagnostic
}

pub struct CheckResult {
pub:
	diagnostics  []diagnostic.Diagnostic
	success      bool
	env          TypeEnv
	typed_ast    typed_ast.BlockExpression
	program_type Type
}

pub fn check(program ast.BlockExpression) CheckResult {
	mut checker := TypeChecker{
		env:         new_env()
		diagnostics: []diagnostic.Diagnostic{}
	}

	typed_block, program_type := checker.check_block(program)

	return CheckResult{
		diagnostics:  checker.diagnostics
		success:      checker.diagnostics.len == 0
		env:          checker.env
		typed_ast:    typed_block
		program_type: program_type
	}
}

fn (mut c TypeChecker) check_block(block ast.BlockExpression) (typed_ast.BlockExpression, Type) {
	mut typed_body := []typed_ast.BlockItem{}
	mut last_type := t_none()

	for node in block.body {
		is_stmt := node is ast.Statement
		if is_stmt {
			stmt := node as ast.Statement
			typed_stmt, typ := c.check_statement(stmt)
			typed_body << typed_ast.BlockItem{
				is_statement: true
				statement:    typed_stmt
			}
			last_type = typ
		} else {
			expr := node as ast.Expression
			typed_expr, typ := c.check_expr(expr)
			typed_body << typed_ast.BlockItem{
				is_statement: false
				expression:   typed_expr
			}
			last_type = typ
		}
	}

	return typed_ast.BlockExpression{
		body: typed_body
		span: block.span
	}, last_type
}

fn (mut c TypeChecker) check_statement(stmt ast.Statement) (typed_ast.Statement, Type) {
	match stmt {
		ast.VariableBinding {
			typed_init, init_type := c.check_expr(stmt.init)
			c.env.define(stmt.identifier.name, init_type)
			s := typed_ast.Statement(typed_ast.VariableBinding{
				identifier: convert_identifier(stmt.identifier)
				typ:        convert_optional_type_id(stmt.typ)
				init:       typed_init
				span:       stmt.span
			})
			return s, t_none()
		}
		ast.ConstBinding {
			typed_init, init_type := c.check_expr(stmt.init)
			c.env.define(stmt.identifier.name, init_type)
			s := typed_ast.Statement(typed_ast.ConstBinding{
				identifier: convert_identifier(stmt.identifier)
				typ:        convert_optional_type_id(stmt.typ)
				init:       typed_init
				span:       stmt.span
			})
			return s, t_none()
		}
		ast.TypePatternBinding {
			typed_init, _ := c.check_expr(stmt.init)
			s := typed_ast.Statement(typed_ast.TypePatternBinding{
				typ:  convert_type_identifier(stmt.typ)
				init: typed_init
				span: stmt.span
			})
			return s, t_none()
		}
		ast.FunctionDeclaration {
			mut param_types := []Type{}
			for param in stmt.params {
				if pt := param.typ {
					if resolved := c.resolve_type_identifier(pt) {
						param_types << resolved
					} else {
						param_types << t_none()
					}
				} else {
					param_types << t_none()
				}
			}

			mut ret_type := t_none()
			if rt := stmt.return_type {
				if resolved := c.resolve_type_identifier(rt) {
					ret_type = resolved
				}
			}

			func_type := TypeFunction{
				params: param_types
				ret:    ret_type
			}
			c.env.register_function(stmt.identifier.name, func_type)
			c.env.define(stmt.identifier.name, func_type)

			c.env.push_scope()
			for i, param in stmt.params {
				c.env.define(param.identifier.name, param_types[i])
			}
			typed_body, _ := c.check_expr(stmt.body)
			c.env.pop_scope()

			mut typed_params := []typed_ast.FunctionParameter{}
			for p in stmt.params {
				typed_params << typed_ast.FunctionParameter{
					identifier: convert_identifier(p.identifier)
					typ:        convert_optional_type_id(p.typ)
				}
			}

			s := typed_ast.Statement(typed_ast.FunctionDeclaration{
				identifier:  convert_identifier(stmt.identifier)
				return_type: convert_optional_type_id(stmt.return_type)
				error_type:  convert_optional_type_id(stmt.error_type)
				params:      typed_params
				body:        typed_body
				span:        stmt.span
			})
			return s, t_none()
		}
		ast.StructDeclaration {
			mut typed_fields := []typed_ast.StructField{}
			for f in stmt.fields {
				mut typed_init := ?typed_ast.Expression(none)
				if init := f.init {
					typed_expr, _ := c.check_expr(init)
					typed_init = typed_expr
				}
				typed_fields << typed_ast.StructField{
					identifier: convert_identifier(f.identifier)
					typ:        convert_type_identifier(f.typ)
					init:       typed_init
				}
			}

			s := typed_ast.Statement(typed_ast.StructDeclaration{
				identifier: convert_identifier(stmt.identifier)
				fields:     typed_fields
				span:       stmt.span
			})
			return s, t_none()
		}
		ast.EnumDeclaration {
			typed_variants := stmt.variants.map(fn (v ast.EnumVariant) typed_ast.EnumVariant {
				return typed_ast.EnumVariant{
					identifier: convert_identifier(v.identifier)
					payload:    v.payload.map(convert_type_identifier)
				}
			})

			s := typed_ast.Statement(typed_ast.EnumDeclaration{
				identifier: convert_identifier(stmt.identifier)
				variants:   typed_variants
				span:       stmt.span
			})
			return s, t_none()
		}
		ast.ImportDeclaration {
			s := typed_ast.Statement(typed_ast.ImportDeclaration{
				path:       stmt.path
				specifiers: stmt.specifiers.map(fn (s ast.ImportSpecifier) typed_ast.ImportSpecifier {
					return typed_ast.ImportSpecifier{
						identifier: typed_ast.Identifier{
							name: s.identifier.name
							span: s.identifier.span
						}
					}
				})
				span:       stmt.span
			})
			return s, t_none()
		}
		ast.ExportDeclaration {
			inner_stmt, typ := c.check_statement(stmt.declaration)
			s := typed_ast.Statement(typed_ast.ExportDeclaration{
				declaration: inner_stmt
				span:        stmt.span
			})
			return s, typ
		}
	}
}

fn (mut c TypeChecker) check_expr(expr ast.Expression) (typed_ast.Expression, Type) {
	match expr {
		ast.NumberLiteral {
			typ := if expr.value.contains('.') { t_float() } else { t_int() }
			return typed_ast.NumberLiteral{
				value: expr.value
				span:  expr.span
			}, typ
		}
		ast.StringLiteral {
			return typed_ast.StringLiteral{
				value: expr.value
				span:  expr.span
			}, t_string()
		}
		ast.InterpolatedString {
			mut typed_parts := []typed_ast.Expression{}
			for part in expr.parts {
				typed_part, _ := c.check_expr(part)
				typed_parts << typed_part
			}
			return typed_ast.InterpolatedString{
				parts: typed_parts
				span:  expr.span
			}, t_string()
		}
		ast.BooleanLiteral {
			return typed_ast.BooleanLiteral{
				value: expr.value
				span:  expr.span
			}, t_bool()
		}
		ast.NoneExpression {
			return typed_ast.NoneExpression{
				span: expr.span
			}, t_none()
		}
		ast.Identifier {
			typ := c.env.lookup(expr.name) or { t_none() }
			return typed_ast.Identifier{
				name: expr.name
				span: expr.span
			}, typ
		}
		ast.BinaryExpression {
			typed_left, _ := c.check_expr(expr.left)
			typed_right, _ := c.check_expr(expr.right)
			return typed_ast.BinaryExpression{
				left:  typed_left
				right: typed_right
				op:    typed_ast.Operator{
					kind: expr.op.kind
				}
				span:  expr.span
			}, t_int()
		}
		ast.UnaryExpression {
			typed_inner, inner_type := c.check_expr(expr.expression)
			return typed_ast.UnaryExpression{
				expression: typed_inner
				op:         typed_ast.Operator{
					kind: expr.op.kind
				}
				span:       expr.span
			}, inner_type
		}
		ast.FunctionExpression {
			mut param_types := []Type{}
			for param in expr.params {
				if pt := param.typ {
					if resolved := c.resolve_type_identifier(pt) {
						param_types << resolved
					} else {
						param_types << t_none()
					}
				} else {
					param_types << t_none()
				}
			}

			mut ret_type := t_none()
			if rt := expr.return_type {
				if resolved := c.resolve_type_identifier(rt) {
					ret_type = resolved
				}
			}

			c.env.push_scope()
			for i, param in expr.params {
				c.env.define(param.identifier.name, param_types[i])
			}
			typed_body, body_type := c.check_expr(expr.body)
			c.env.pop_scope()

			if expr.return_type == none {
				ret_type = body_type
			}

			func_type := TypeFunction{
				params: param_types
				ret:    ret_type
			}

			mut typed_params := []typed_ast.FunctionParameter{}
			for p in expr.params {
				typed_params << typed_ast.FunctionParameter{
					identifier: convert_identifier(p.identifier)
					typ:        convert_optional_type_id(p.typ)
				}
			}

			return typed_ast.FunctionExpression{
				return_type: convert_optional_type_id(expr.return_type)
				error_type:  convert_optional_type_id(expr.error_type)
				params:      typed_params
				body:        typed_body
				span:        expr.span
			}, func_type
		}
		ast.FunctionCallExpression {
			mut typed_args := []typed_ast.Expression{}
			for arg in expr.arguments {
				typed_arg, _ := c.check_expr(arg)
				typed_args << typed_arg
			}

			ret_type := if func_type := c.env.lookup_function(expr.identifier.name) {
				func_type.ret
			} else {
				t_none()
			}

			return typed_ast.FunctionCallExpression{
				identifier: convert_identifier(expr.identifier)
				arguments:  typed_args
				span:       expr.span
			}, ret_type
		}
		ast.BlockExpression {
			c.env.push_scope()
			typed_block, last_type := c.check_block(expr)
			c.env.pop_scope()
			return typed_block, last_type
		}
		ast.IfExpression {
			typed_cond, _ := c.check_expr(expr.condition)
			typed_body, then_type := c.check_expr(expr.body)

			mut typed_else := ?typed_ast.Expression(none)
			if else_body := expr.else_body {
				typed_else_body, _ := c.check_expr(else_body)
				typed_else = typed_else_body
			}

			return typed_ast.IfExpression{
				condition: typed_cond
				body:      typed_body
				span:      expr.span
				else_body: typed_else
			}, then_type
		}
		ast.ArrayExpression {
			mut typed_elements := []typed_ast.Expression{}
			mut elem_type := t_none()
			for elem in expr.elements {
				typed_elem, et := c.check_expr(elem)
				typed_elements << typed_elem
				elem_type = et
			}
			return typed_ast.ArrayExpression{
				elements: typed_elements
				span:     expr.span
			}, t_array(elem_type)
		}
		ast.ArrayIndexExpression {
			typed_arr, arr_type := c.check_expr(expr.expression)
			typed_idx, _ := c.check_expr(expr.index)
			return typed_ast.ArrayIndexExpression{
				expression: typed_arr
				index:      typed_idx
				span:       expr.span
			}, arr_type
		}
		ast.StructInitExpression {
			mut typed_fields := []typed_ast.StructInitField{}
			for field in expr.fields {
				typed_init, _ := c.check_expr(field.init)
				typed_fields << typed_ast.StructInitField{
					identifier: convert_identifier(field.identifier)
					init:       typed_init
				}
			}
			return typed_ast.StructInitExpression{
				identifier: convert_identifier(expr.identifier)
				fields:     typed_fields
				span:       expr.span
			}, t_none()
		}
		ast.PropertyAccessExpression {
			typed_left, left_type := c.check_expr(expr.left)
			typed_right, _ := c.check_expr(expr.right)
			return typed_ast.PropertyAccessExpression{
				left:  typed_left
				right: typed_right
				span:  expr.span
			}, left_type
		}
		ast.MatchExpression {
			typed_subject, _ := c.check_expr(expr.subject)
			mut typed_arms := []typed_ast.MatchArm{}
			mut result_type := t_none()
			for arm in expr.arms {
				typed_pattern, _ := c.check_expr(arm.pattern)
				typed_body, arm_type := c.check_expr(arm.body)
				typed_arms << typed_ast.MatchArm{
					pattern: typed_pattern
					body:    typed_body
				}
				result_type = arm_type
			}
			return typed_ast.MatchExpression{
				subject: typed_subject
				arms:    typed_arms
				span:    expr.span
			}, result_type
		}
		ast.OrExpression {
			typed_inner, inner_type := c.check_expr(expr.expression)
			typed_body, _ := c.check_expr(expr.body)
			return typed_ast.OrExpression{
				expression:    typed_inner
				receiver:      convert_optional_identifier(expr.receiver)
				body:          typed_body
				resolved_type: inner_type
				span:          expr.span
			}, inner_type
		}
		ast.ErrorExpression {
			typed_inner, typ := c.check_expr(expr.expression)
			return typed_ast.ErrorExpression{
				expression: typed_inner
				span:       expr.span
			}, typ
		}
		ast.RangeExpression {
			typed_start, _ := c.check_expr(expr.start)
			typed_end, _ := c.check_expr(expr.end)
			return typed_ast.RangeExpression{
				start: typed_start
				end:   typed_end
				span:  expr.span
			}, t_array(t_int())
		}
		ast.SpreadExpression {
			if inner := expr.expression {
				typed_inner, inner_type := c.check_expr(inner)
				return typed_ast.SpreadExpression{
					expression: typed_inner
					span:       expr.span
				}, inner_type
			}
			return typed_ast.SpreadExpression{
				expression: none
				span:       expr.span
			}, t_none()
		}
		ast.AssertExpression {
			typed_cond, _ := c.check_expr(expr.expression)
			typed_msg, _ := c.check_expr(expr.message)
			return typed_ast.AssertExpression{
				expression: typed_cond
				message:    typed_msg
				span:       expr.span
			}, t_none()
		}
		ast.PropagateNoneExpression {
			typed_inner, inner_type := c.check_expr(expr.expression)
			return typed_ast.PropagateNoneExpression{
				expression:    typed_inner
				resolved_type: inner_type
				span:          expr.span
			}, inner_type
		}
		ast.WildcardPattern {
			return typed_ast.WildcardPattern{
				span: expr.span
			}, t_none()
		}
		ast.OrPattern {
			mut typed_patterns := []typed_ast.Expression{}
			for pattern in expr.patterns {
				typed_pattern, _ := c.check_expr(pattern)
				typed_patterns << typed_pattern
			}
			return typed_ast.OrPattern{
				patterns: typed_patterns
				span:     expr.span
			}, t_none()
		}
		ast.ErrorNode {
			return typed_ast.ErrorNode{
				message: expr.message
				span:    expr.span
			}, t_none()
		}
		ast.TypeIdentifier {
			return convert_type_identifier(expr), t_none()
		}
	}
}

fn (c TypeChecker) resolve_type_identifier(t ast.TypeIdentifier) ?Type {
	if t.is_function {
		mut param_types := []Type{}
		for param_type in t.param_types {
			resolved := c.resolve_type_identifier(param_type) or { return none }
			param_types << resolved
		}

		mut ret_type := t_none()
		if rt := t.return_type {
			ret_type = c.resolve_type_identifier(*rt) or { return none }
		}

		return Type(TypeFunction{
			params: param_types
			ret:    ret_type
		})
	}

	if t.is_array {
		elem := t.element_type or { return none }
		elem_type := c.resolve_type_identifier(*elem) or { return none }
		return t_array(elem_type)
	}

	name := t.identifier.name
	return c.env.lookup_type(name)
}

fn convert_type_identifier(t ast.TypeIdentifier) typed_ast.TypeIdentifier {
	return typed_ast.TypeIdentifier{
		is_array:     t.is_array
		is_option:    t.is_option
		is_function:  t.is_function
		identifier:   typed_ast.Identifier{
			name: t.identifier.name
			span: t.identifier.span
		}
		element_type: convert_optional_type_identifier(t.element_type)
		param_types:  t.param_types.map(fn (pt ast.TypeIdentifier) typed_ast.TypeIdentifier {
			return convert_type_identifier(pt)
		})
		return_type:  convert_optional_type_identifier(t.return_type)
		error_type:   convert_optional_type_identifier(t.error_type)
		span:         t.span
	}
}

fn convert_optional_type_identifier(t ?&ast.TypeIdentifier) ?&typed_ast.TypeIdentifier {
	if ti := t {
		converted := convert_type_identifier(*ti)
		return &converted
	}
	return none
}

fn convert_optional_type_id(t ?ast.TypeIdentifier) ?typed_ast.TypeIdentifier {
	if ti := t {
		return convert_type_identifier(ti)
	}
	return none
}

fn convert_optional_identifier(id ?ast.Identifier) ?typed_ast.Identifier {
	if i := id {
		return convert_identifier(i)
	}
	return none
}

fn convert_identifier(id ast.Identifier) typed_ast.Identifier {
	return typed_ast.Identifier{
		name: id.name
		span: id.span
	}
}
