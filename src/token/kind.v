module token

pub enum Kind {
	eof error identifier literal_number literal_string literal_string_interpolation literal_char
	logical_and logical_or bitwise_and bitwise_or bitwise_xor bitwise_not
	kw_comptime kw_const kw_enum kw_error kw_if kw_else kw_function kw_import kw_from
	kw_true kw_false kw_assert kw_export kw_struct kw_in kw_match kw_none kw_or
	punc_arrow punc_comma punc_colon punc_semicolon punc_dot punc_dotdot punc_ellipsis
	punc_open_paren punc_close_paren punc_open_brace punc_close_brace punc_open_bracket punc_close_bracket
	punc_question_mark punc_exclamation_mark punc_at punc_equals punc_equals_comparator punc_not_equal
	punc_gt punc_lt punc_gte punc_lte punc_plus punc_plusplus punc_minus punc_minusminus
	punc_mul punc_div punc_mod _end_
}

pub fn (kind Kind) str() string {
	return match kind {
		.eof { 'EOF' } .error { '<error>' } .identifier { 'identifier' } .literal_number { 'number' }
		.literal_string { 'string' } .literal_string_interpolation { 'interpolated string' } .literal_char { 'char' }
		.logical_and { '&&' } .logical_or { '||' } .bitwise_and { '&' } .bitwise_or { '|' } .bitwise_xor { '^' } .bitwise_not { '~' }
		.kw_comptime { 'comptime' } .kw_const { 'const' } .kw_enum { 'enum' } .kw_error { 'error' } .kw_if { 'if' } .kw_else { 'else' }
		.kw_function { 'fn' } .kw_import { 'import' } .kw_from { 'from' } .kw_true { 'true' } .kw_false { 'false' }
		.kw_assert { 'assert' } .kw_export { 'export' } .kw_struct { 'struct' } .kw_in { 'in' } .kw_match { 'match' }
		.kw_none { 'none' } .kw_or { 'or' } .punc_arrow { '->' } .punc_comma { ',' } .punc_colon { ':' } .punc_semicolon { ';' }
		.punc_dot { '.' } .punc_dotdot { '..' } .punc_ellipsis { '...' } .punc_open_paren { '(' } .punc_close_paren { ')' }
		.punc_open_brace { '{' } .punc_close_brace { '}' } .punc_open_bracket { '[' } .punc_close_bracket { ']' }
		.punc_question_mark { '?' } .punc_exclamation_mark { '!' } .punc_at { '@' } .punc_equals { '=' }
		.punc_equals_comparator { '==' } .punc_not_equal { '!=' } .punc_gt { '>' } .punc_lt { '<' } .punc_gte { '>=' } .punc_lte { '<=' }
		.punc_plus { '+' } .punc_plusplus { '++' } .punc_minus { '-' } .punc_minusminus { '--' }
		.punc_mul { '*' } .punc_div { '/' } .punc_mod { '%' } ._end_ { '<end>' }
	}
}
