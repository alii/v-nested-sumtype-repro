module checker

import src.ast
import src.type_def

pub struct TypeEnv {
mut:
	types     map[string]type_def.Type
	functions map[string]type_def.TypeFunction
	structs   map[string]type_def.TypeStruct
	enums     map[string]type_def.TypeEnum
}

pub fn check(expr ast.Expression) !type_def.Type {
	mut env := TypeEnv{}
	return env.check_expr(expr)
}

fn (mut env TypeEnv) check_statement(stmt ast.Statement) !type_def.Type {
	match stmt {
		ast.VariableBinding {
			t := env.check_expr(stmt.init)!
			env.types[stmt.identifier.name] = t
			return type_def.Type(type_def.TypeNone{})
		}
		ast.ConstBinding {
			t := env.check_expr(stmt.init)!
			env.types[stmt.identifier.name] = t
			return type_def.Type(type_def.TypeNone{})
		}
		ast.TypePatternBinding {
			env.check_expr(stmt.init)!
			return type_def.Type(type_def.TypeNone{})
		}
		ast.FunctionDeclaration {
			body_type := env.check_expr(stmt.body)!
			env.types[stmt.identifier.name] = type_def.Type(type_def.TypeFunction{
				params:      []
				return_type: body_type
			})
			return type_def.Type(type_def.TypeNone{})
		}
		ast.StructDeclaration {
			return type_def.Type(type_def.TypeNone{})
		}
		ast.EnumDeclaration {
			return type_def.Type(type_def.TypeNone{})
		}
		ast.ImportDeclaration {
			return type_def.Type(type_def.TypeNone{})
		}
		ast.ExportDeclaration {
			return env.check_statement(stmt.declaration)
		}
	}
}

fn (mut env TypeEnv) check_expr(expr ast.Expression) !type_def.Type {
	match expr {
		ast.BlockExpression {
			mut last_type := type_def.Type(type_def.TypeNone{})
			last_idx := expr.body.len - 1
			for i, item in expr.body {
				is_last := i == last_idx
				if item.is_statement {
					env.check_statement(item.statement)!
					if is_last {
						last_type = type_def.Type(type_def.TypeNone{})
					}
				} else {
					t := env.check_expr(item.expression)!
					if is_last {
						last_type = t
					}
				}
			}
			return last_type
		}
		ast.NumberLiteral {
			if expr.value.contains('.') {
				return type_def.Type(type_def.TypeString{}) // float as string for now
			}
			return type_def.Type(type_def.TypeInt{})
		}
		ast.StringLiteral {
			return type_def.Type(type_def.TypeString{})
		}
		ast.InterpolatedString {
			for part in expr.parts {
				env.check_expr(part)!
			}
			return type_def.Type(type_def.TypeString{})
		}
		ast.BooleanLiteral {
			return type_def.Type(type_def.TypeBool{})
		}
		ast.NoneExpression {
			return type_def.Type(type_def.TypeNone{})
		}
		ast.Identifier {
			if t := env.types[expr.name] {
				return t
			}
			return type_def.Type(type_def.TypeNone{})
		}
		ast.BinaryExpression {
			left_type := env.check_expr(expr.left)!
			right_type := env.check_expr(expr.right)!
			_ = left_type
			_ = right_type
			return type_def.Type(type_def.TypeInt{})
		}
		ast.UnaryExpression {
			inner := env.check_expr(expr.expression)!
			return inner
		}
		ast.IfExpression {
			cond_type := env.check_expr(expr.condition)!
			_ = cond_type
			body_type := env.check_expr(expr.body)!
			if else_body := expr.else_body {
				else_type := env.check_expr(else_body)!
				_ = else_type
			}
			return body_type
		}
		ast.MatchExpression {
			subject_type := env.check_expr(expr.subject)!
			_ = subject_type
			mut result_type := type_def.Type(type_def.TypeNone{})
			for arm in expr.arms {
				env.check_expr(arm.pattern)!
				result_type = env.check_expr(arm.body)!
			}
			return result_type
		}
		ast.ArrayExpression {
			mut elem_type := type_def.Type(type_def.TypeNone{})
			for elem in expr.elements {
				elem_type = env.check_expr(elem)!
			}
			return type_def.Type(type_def.TypeArray{ element: elem_type })
		}
		ast.ArrayIndexExpression {
			arr_type := env.check_expr(expr.expression)!
			env.check_expr(expr.index)!
			if arr_type is type_def.TypeArray {
				return arr_type.element
			}
			return type_def.Type(type_def.TypeNone{})
		}
		ast.RangeExpression {
			env.check_expr(expr.start)!
			env.check_expr(expr.end)!
			return type_def.Type(type_def.TypeArray{ element: type_def.Type(type_def.TypeInt{}) })
		}
		ast.SpreadExpression {
			if inner := expr.expression {
				return env.check_expr(inner)
			}
			return type_def.Type(type_def.TypeNone{})
		}
		ast.FunctionExpression {
			body_type := env.check_expr(expr.body)!
			return type_def.Type(type_def.TypeFunction{
				params:      []
				return_type: body_type
			})
		}
		ast.FunctionCallExpression {
			for arg in expr.arguments {
				env.check_expr(arg)!
			}
			if fn_type := env.types[expr.identifier.name] {
				if fn_type is type_def.TypeFunction {
					return fn_type.return_type
				}
			}
			return type_def.Type(type_def.TypeNone{})
		}
		ast.PropertyAccessExpression {
			left_type := env.check_expr(expr.left)!
			_ = left_type
			env.check_expr(expr.right)!
			return type_def.Type(type_def.TypeNone{})
		}
		ast.StructInitExpression {
			for field in expr.fields {
				env.check_expr(field.init)!
			}
			return type_def.Type(type_def.TypeNone{})
		}
		ast.AssertExpression {
			env.check_expr(expr.expression)!
			env.check_expr(expr.message)!
			return type_def.Type(type_def.TypeNone{})
		}
		ast.ErrorExpression {
			inner := env.check_expr(expr.expression)!
			return type_def.Type(type_def.TypeResult{
				ok_type:  type_def.Type(type_def.TypeNone{})
				err_type: inner
			})
		}
		ast.OrExpression {
			env.check_expr(expr.expression)!
			env.check_expr(expr.body)!
			return expr.resolved_type
		}
		ast.PropagateNoneExpression {
			env.check_expr(expr.expression)!
			return expr.resolved_type
		}
		ast.WildcardPattern {
			return type_def.Type(type_def.TypeNone{})
		}
		ast.OrPattern {
			for pattern in expr.patterns {
				env.check_expr(pattern)!
			}
			return type_def.Type(type_def.TypeNone{})
		}
		ast.ErrorNode {
			return type_def.Type(type_def.TypeNone{})
		}
		ast.TypeIdentifier {
			return type_def.Type(type_def.TypeNone{})
		}
	}
}
