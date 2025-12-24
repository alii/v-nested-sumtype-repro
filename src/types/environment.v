module types

import type_def { Type, TypeFunction, t_bool, t_float, t_int, t_none, t_string }

pub struct TypeEnv {
mut:
	scopes    []map[string]Type
	functions map[string]TypeFunction
}

pub fn new_env() TypeEnv {
	return TypeEnv{
		scopes:    [map[string]Type{}]
		functions: map[string]TypeFunction{}
	}
}

pub fn (mut e TypeEnv) push_scope() {
	e.scopes << map[string]Type{}
}

pub fn (mut e TypeEnv) pop_scope() {
	if e.scopes.len > 1 {
		e.scopes.pop()
	}
}

pub fn (mut e TypeEnv) define(name string, t Type) {
	if e.scopes.len > 0 {
		e.scopes[e.scopes.len - 1][name] = t
	}
}

pub fn (e TypeEnv) lookup(name string) ?Type {
	for i := e.scopes.len - 1; i >= 0; i-- {
		if t := e.scopes[i][name] {
			return t
		}
	}
	return none
}

pub fn (mut e TypeEnv) register_function(name string, f TypeFunction) {
	e.functions[name] = f
}

pub fn (e TypeEnv) lookup_function(name string) ?TypeFunction {
	return e.functions[name] or { return none }
}

pub fn (e TypeEnv) lookup_type(name string) ?Type {
	match name {
		'Int' { return t_int() }
		'Float' { return t_float() }
		'String' { return t_string() }
		'Bool' { return t_bool() }
		'None' { return t_none() }
		else {}
	}
	return none
}
