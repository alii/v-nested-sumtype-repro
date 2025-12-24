module type_def

pub struct TypeInt {}
pub struct TypeString {}
pub struct TypeBool {}
pub struct TypeNone {}
pub struct TypeArray {
pub:
	element Type
}
pub struct TypeOption {
pub:
	inner Type
}
pub struct TypeResult {
pub:
	ok_type  Type
	err_type Type
}
pub struct TypeFunction {
pub:
	params     []Type
	return_type Type
}
pub struct TypeStruct {
pub:
	name   string
	fields map[string]Type
}
pub struct TypeEnum {
pub:
	name     string
	variants map[string][]Type
	id       int
}

pub type Type = TypeArray
	| TypeBool
	| TypeEnum
	| TypeFunction
	| TypeInt
	| TypeNone
	| TypeOption
	| TypeResult
	| TypeString
	| TypeStruct
