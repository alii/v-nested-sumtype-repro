module type_def

pub type Type = TypePrimitive
	| TypeArray
	| TypeOption
	| TypeFunction
	| TypeNone

pub enum PrimitiveKind {
	t_int
	t_float
	t_string
	t_bool
}

pub struct TypePrimitive {
pub:
	kind PrimitiveKind
}

pub struct TypeArray {
pub:
	element Type
}

pub struct TypeOption {
pub:
	inner Type
}

pub struct TypeFunction {
pub:
	params []Type
	ret    Type
}

pub struct TypeNone {}

pub fn t_int() Type {
	return TypePrimitive{ kind: .t_int }
}

pub fn t_float() Type {
	return TypePrimitive{ kind: .t_float }
}

pub fn t_string() Type {
	return TypePrimitive{ kind: .t_string }
}

pub fn t_bool() Type {
	return TypePrimitive{ kind: .t_bool }
}

pub fn t_none() Type {
	return TypeNone{}
}
