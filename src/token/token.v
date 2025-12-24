module token

pub enum Kind {
	// Keywords
	kw_let
	kw_const
	kw_fn
	kw_if
	kw_else
	kw_match
	kw_for
	kw_in
	kw_return
	kw_struct
	kw_enum
	kw_import
	kw_export
	kw_true
	kw_false
	kw_none
	kw_mut
	kw_pub

	// Literals
	lit_int
	lit_float
	lit_string
	lit_ident

	// Punctuation
	punc_plus
	punc_minus
	punc_mul
	punc_div
	punc_mod
	punc_equals
	punc_equals_comparator
	punc_not_equal
	punc_lt
	punc_gt
	punc_lte
	punc_gte
	punc_exclamation_mark
	punc_question_mark
	punc_ampersand
	punc_pipe
	punc_caret
	punc_tilde
	punc_left_shift
	punc_right_shift
	punc_arrow
	punc_fat_arrow
	punc_dot
	punc_double_dot
	punc_triple_dot
	punc_comma
	punc_colon
	punc_semicolon
	punc_at
	punc_hash

	// Brackets
	punc_lparen
	punc_rparen
	punc_lbrace
	punc_rbrace
	punc_lbracket
	punc_rbracket

	// Logical
	logical_and
	logical_or

	// Special
	eof
	error
	newline
	whitespace
	comment
}

pub struct Token {
pub:
	kind    Kind
	lexeme  string
	line    int
	column  int
}
