module token

@[inline; minify]
pub struct Token {
pub:
	kind           Kind     // The token number/enum; for quick comparisons
	literal        ?string  // Literal representation of the token
	line           int      // The line number in the source where the token occurred
	column         int      // The column number in the source where the token occurred
	leading_trivia []Trivia // Whitespace/comments before this token
}

pub fn (t &Token) str() string {
	if literal := t.literal {
		if t.kind == .literal_string {
			return '\'${literal}\''
		}
	}

	return t.literal or { t.kind.str() }
}
