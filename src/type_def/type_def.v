module type_def

pub type Type = TypeNone

pub struct TypeNone {}

pub fn t_none() Type {
	return TypeNone{}
}
