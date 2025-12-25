module state

pub struct ScannerState {
mut:
	pos    int
	column int
	line   int
}

pub fn (mut s ScannerState) get_pos() int { return s.pos }
pub fn (mut s ScannerState) incr_pos() { s.pos++ }
pub fn (s ScannerState) get_line() int { return s.line }
pub fn (s ScannerState) get_column() int { return s.column }
pub fn (mut s ScannerState) incr_line() { s.line++; s.column = 0 }
pub fn (mut s ScannerState) incr_column() { s.column++ }
