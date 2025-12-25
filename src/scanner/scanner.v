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
	pending_trivia     []token.Trivia
	token_start_column int
	token_start_line   int
}

@[inline]
pub fn new_scanner(input string) &Scanner {
	return &Scanner{
		input:       input
		state:       &state.ScannerState{}
		diagnostics: []diagnostic.Diagnostic{}
	}
}

fn (mut s Scanner) add_error(message string) {
	s.diagnostics << diagnostic.error_at(s.state.get_line(), s.state.get_column(), message)
}

pub fn (s Scanner) get_diagnostics() []diagnostic.Diagnostic {
	return s.diagnostics
}

fn (mut s Scanner) collect_trivia() {
	for s.state.get_pos() < s.input.len {
		ch := s.peek_char()

		// Collect whitespace (spaces, tabs)
		if ch == ` ` || ch == `\t` {
			start := s.state.get_pos()
			for s.state.get_pos() < s.input.len {
				c := s.peek_char()
				if c != ` ` && c != `\t` {
					break
				}
				s.incr_pos()
			}
			text := s.input[start..s.state.get_pos()]
			s.pending_trivia << token.Trivia{
				kind: .whitespace
				text: text
			}
			continue
		}

		// Collect newlines
		if ch == `\n` {
			s.incr_pos()
			s.pending_trivia << token.Trivia{
				kind: .newline
				text: '\n'
			}
			continue
		}

		// Collect line comments
		if ch == `/` && s.state.get_pos() + 1 < s.input.len && s.input[s.state.get_pos() + 1] == `/` {
			start := s.state.get_pos()
			for s.state.get_pos() < s.input.len && s.peek_char() != `\n` {
				s.incr_pos()
			}
			text := s.input[start..s.state.get_pos()]
			s.pending_trivia << token.Trivia{
				kind: .line_comment
				text: text
			}
			continue
		}

		break
	}
}

pub fn (mut s Scanner) scan_next() token.Token {
	s.collect_trivia()

	s.token_start_column = s.state.get_column()
	s.token_start_line = s.state.get_line()

	if s.state.get_pos() == s.input.len {
		return s.new_token(.eof, none)
	}

	ch := s.peek_char()
	s.incr_pos()

	if token.is_valid_identifier(ch.ascii_str(), false) {
		identifier := s.scan_identifier(ch)

		if unwrapped := identifier.literal {
			if keyword_kind := token.match_keyword(unwrapped) {
				return s.new_token_with_trivia(keyword_kind, none, identifier.leading_trivia)
			}
		}

		return identifier
	}

	if ch == `-` && s.peek_char() == `>` {
		s.incr_pos()
		return s.new_token(.punc_arrow, none)
	}

	// Must do this check before checking for numbers
	if ch == `.` && s.peek_char() == `.` {
		s.incr_pos()
		return s.new_token(.punc_dotdot, none)
	}

	if ch.is_alnum() {
		if ch.is_digit() {
			return s.scan_number(ch)
		}

		return s.scan_identifier(ch)
	}

	if token.is_quote(ch) {
		mut result := ''
		for {
			next := s.peek_char()
			if next == 0 || next == `\n` || next == ch {
				if next == ch {
					s.incr_pos()
				}
				break
			}
			s.incr_pos()
			result += next.ascii_str()
		}
		return s.new_token(.literal_string, result)
	}

	return match ch {
		`,` {
			s.new_token(.punc_comma, none)
		}
		`(` {
			s.new_token(.punc_open_paren, none)
		}
		`)` {
			s.new_token(.punc_close_paren, none)
		}
		`{` {
			s.new_token(.punc_open_brace, none)
		}
		`}` {
			s.new_token(.punc_close_brace, none)
		}
		`[` {
			s.new_token(.punc_open_bracket, none)
		}
		`]` {
			s.new_token(.punc_close_bracket, none)
		}
		`;` {
			s.new_token(.punc_semicolon, none)
		}
		`.` {
			s.new_token(.punc_dot, none)
		}
		`+` {
			s.new_token(.punc_plus, none)
		}
		`-` {
			s.new_token(.punc_minus, none)
		}
		`*` {
			s.new_token(.punc_mul, none)
		}
		`%` {
			s.new_token(.punc_mod, none)
		}
		`!` {
			s.new_token(.punc_exclamation_mark, none)
		}
		`?` {
			s.new_token(.punc_question_mark, none)
		}
		`:` {
			s.new_token(.punc_colon, none)
		}
		`>` {
			s.new_token(.punc_gt, none)
		}
		`<` {
			s.new_token(.punc_lt, none)
		}
		`/` {
			s.new_token(.punc_div, none)
		}
		`|` {
			s.new_token(.bitwise_or, none)
		}
		`=` {
			s.new_token(.punc_equals, none)
		}
		else {
			s.add_error("Unexpected character '${ch.ascii_str()}'")
			return s.new_token(.error, ch.ascii_str())
		}
	}
}

pub fn (mut s Scanner) scan_all() []token.Token {
	mut result := []token.Token{}

	for {
		t := s.scan_next()
		result << t

		if t.kind == .eof {
			break
		}
	}

	return result
}

fn (mut s Scanner) new_token(kind token.Kind, literal ?string) token.Token {
	return s.new_token_with_trivia(kind, literal, s.take_trivia())
}

fn (mut s Scanner) new_token_with_trivia(kind token.Kind, literal ?string, trivia []token.Trivia) token.Token {
	return token.Token{
		kind:           kind
		literal:        literal
		line:           s.token_start_line
		column:         s.token_start_column
		leading_trivia: trivia
	}
}

fn (mut s Scanner) take_trivia() []token.Trivia {
	trivia := s.pending_trivia.clone()
	s.pending_trivia.clear()
	return trivia
}

// scan_identifier scans until the next non-alphanumeric character
fn (mut s Scanner) scan_identifier(from u8) token.Token {
	mut result := from.ascii_str()

	for {
		next := result + s.peek_char().ascii_str()

		if token.is_valid_identifier(next, false) {
			s.incr_pos()
			result = next
		} else {
			break
		}
	}

	return s.new_token(.identifier, result)
}

// Not a big fan of how this is implemented right now, it's
// too greedy and requires backtracking to figure out
// if the dots represent other tokens, or just a dotdot
fn (mut s Scanner) scan_number(from u8) token.Token {
	mut result := from.ascii_str()

	mut has_dot := false

	for {
		next := s.peek_char()

		if next == `.` && has_dot {
			result = result[..result.len - 1]
			s.decr_pos()
			break
		}

		if next.is_digit() {
			s.incr_pos()
			result += next.ascii_str()
		} else if next == `.` && !has_dot {
			// Only works if the chars after the dot
			// are also numerical

			has_dot = true
			s.incr_pos()
			result += next.ascii_str()
		} else {
			break
		}
	}

	return s.new_token(.literal_number, result)
}

fn (mut s Scanner) peek_char() u8 {
	if s.state.get_pos() >= s.input.len {
		return 0 // EOF
	}
	return s.input[s.state.get_pos()]
}

pub fn (mut s Scanner) incr_pos() {
	if s.input[s.state.get_pos()] == `\n` {
		s.state.incr_line()
	} else {
		s.state.incr_column()
	}

	s.state.incr_pos()
}

fn (mut s Scanner) decr_pos() {
	if s.input[s.state.get_pos()] == `\n` {
		s.state.decr_line()
	} else {
		s.state.decr_column()
	}

	s.state.decr_pos()
}
