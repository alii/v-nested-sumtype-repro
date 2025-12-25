module scanner

import token
import scanner.state
import diagnostic

@[heap]
pub struct Scanner {
	input string
mut:
	state              &state.ScannerState
	diagnostics        []diagnostic.Diagnostic
	token_start_column int
	token_start_line   int
}

pub fn new_scanner(input string) &Scanner {
	return &Scanner{input: input, state: &state.ScannerState{}, diagnostics: []diagnostic.Diagnostic{}}
}

pub fn (s Scanner) get_diagnostics() []diagnostic.Diagnostic { return s.diagnostics }

fn (mut s Scanner) peek() u8 {
	if s.state.get_pos() >= s.input.len { return 0 }
	return s.input[s.state.get_pos()]
}

fn (mut s Scanner) adv() {
	if s.input[s.state.get_pos()] == `\n` { s.state.incr_line() } else { s.state.incr_column() }
	s.state.incr_pos()
}

fn (mut s Scanner) tok(kind token.Kind, lit ?string) token.Token {
	return token.Token{kind: kind, literal: lit, line: s.token_start_line, column: s.token_start_column}
}

pub fn (mut s Scanner) scan_next() token.Token {
	for s.state.get_pos() < s.input.len {
		c := s.peek()
		if c == ` ` || c == `\t` || c == `\n` { s.adv() } else { break }
	}
	s.token_start_column = s.state.get_column()
	s.token_start_line = s.state.get_line()
	if s.state.get_pos() == s.input.len { return s.tok(.eof, none) }

	c := s.peek()
	s.adv()

	if c == `_` || c.is_letter() {
		mut r := c.ascii_str()
		for s.peek().is_letter() || s.peek() == `_` || s.peek().is_digit() { r += s.peek().ascii_str(); s.adv() }
		if kw := token.match_keyword(r) { return s.tok(kw, none) }
		return s.tok(.identifier, r)
	}
	if c.is_digit() {
		mut r := c.ascii_str()
		for s.peek().is_digit() { r += s.peek().ascii_str(); s.adv() }
		return s.tok(.literal_number, r)
	}
	if c == `'` {
		mut r := ''
		for s.peek() != 0 && s.peek() != `\n` && s.peek() != `'` { r += s.peek().ascii_str(); s.adv() }
		if s.peek() == `'` { s.adv() }
		return s.tok(.literal_string, r)
	}
	if c == `-` && s.peek() == `>` { s.adv(); return s.tok(.punc_arrow, none) }
	if c == `.` && s.peek() == `.` { s.adv(); return s.tok(.punc_dotdot, none) }

	return match c {
		`,` { s.tok(.punc_comma, none) }
		`(` { s.tok(.punc_open_paren, none) }
		`)` { s.tok(.punc_close_paren, none) }
		`{` { s.tok(.punc_open_brace, none) }
		`}` { s.tok(.punc_close_brace, none) }
		`[` { s.tok(.punc_open_bracket, none) }
		`]` { s.tok(.punc_close_bracket, none) }
		`;` { s.tok(.punc_semicolon, none) }
		`.` { s.tok(.punc_dot, none) }
		`+` { s.tok(.punc_plus, none) }
		`-` { s.tok(.punc_minus, none) }
		`*` { s.tok(.punc_mul, none) }
		`%` { s.tok(.punc_mod, none) }
		`!` { s.tok(.punc_exclamation_mark, none) }
		`?` { s.tok(.punc_question_mark, none) }
		`:` { s.tok(.punc_colon, none) }
		`>` { s.tok(.punc_gt, none) }
		`<` { s.tok(.punc_lt, none) }
		`/` { s.tok(.punc_div, none) }
		`|` { s.tok(.bitwise_or, none) }
		`=` { s.tok(.punc_equals, none) }
		else { s.tok(.error, c.ascii_str()) }
	}
}

pub fn (mut s Scanner) scan_all() []token.Token {
	mut r := []token.Token{}
	for { t := s.scan_next(); r << t; if t.kind == .eof { break } }
	return r
}
