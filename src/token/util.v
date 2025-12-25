module token

pub const keyword_map = { 'fn': Kind.kw_function }

fn is_name_char(c u8) bool { return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_` || c.is_digit() }

pub fn is_valid_identifier(identifier string, _ bool) bool {
	if identifier.len == 0 { return false }
	if !identifier[0].is_letter() && identifier[0] != `_` { return false }
	for i := 1; i < identifier.len; i++ { if !is_name_char(identifier[i]) { return false } }
	return true
}

pub fn match_keyword(identifier ?string) ?Kind {
	if unwrapped := identifier { return keyword_map[unwrapped] or { return none } }
	return none
}

pub fn is_quote(c char) bool { return c == `'` }
