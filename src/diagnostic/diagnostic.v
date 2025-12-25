module diagnostic

import span { Span, point_span }

pub enum Severity { error }
pub struct Diagnostic {
pub:
	span     Span
	severity Severity
	message  string
}

pub fn error_at(line int, column int, message string) Diagnostic {
	return Diagnostic{span: point_span(line, column), severity: .error, message: message}
}
