module state

const default_column_n = 0

pub struct ScannerState {
mut:
	pos    int
	column int = default_column_n
	line   int
}

@[inline]
pub fn (mut s ScannerState) get_pos() int {
	return s.pos
}

@[inline]
pub fn (mut s ScannerState) incr_pos() {
	s.pos++
}

@[inline]
pub fn (s ScannerState) get_line() int {
	return s.line
}

@[inline]
pub fn (s ScannerState) get_column() int {
	return s.column
}

@[inline]
pub fn (mut s ScannerState) decr_pos() {
	s.pos--
}

@[inline]
pub fn (mut s ScannerState) decr_line() {
	s.line--
}

@[inline]
pub fn (mut s ScannerState) decr_column() {
	s.column--
}

pub fn (mut s ScannerState) incr_line() {
	s.line++
	s.column = default_column_n
}

pub fn (mut s ScannerState) incr_column() {
	s.column++
}
