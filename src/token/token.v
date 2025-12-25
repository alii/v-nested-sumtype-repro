module token

@[inline; minify]
pub struct Token {
pub:
	kind    Kind
	literal ?string
	line    int
	column  int
}

pub fn (t &Token) str() string {
	if literal := t.literal {
		if t.kind == .literal_string {
			return '\'${literal}\''
		}
	}

	return t.literal or { t.kind.str() }
}
