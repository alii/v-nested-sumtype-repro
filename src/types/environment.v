module types

import type_def { Type }

pub struct TypeEnv {
mut:
	bindings map[string]Type
}

pub fn new_env() TypeEnv {
	return TypeEnv{
		bindings: map[string]Type{}
	}
}

pub fn (mut e TypeEnv) define(name string, t Type) {
	e.bindings[name] = t
}
