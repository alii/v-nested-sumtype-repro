module main

// Minimal repro for nested sum type segfault on Linux x86_64 with -prod

struct Foo {
	value int
	span  int
}

struct Bar {
	name string
	span int
}

struct Baz {
	data string
	span int
}

struct Container {
	body []Node
	span int
}

type Statement = Foo | Bar
type Expression = Baz | Container
type Node = Statement | Expression

fn process_node(node Node) int {
	return match node {
		Statement { node.span }
		Expression { node.span }
	}
}

fn process_container(c Container) int {
	mut sum := 0
	for i, node in c.body {
		is_last := i == c.body.len - 1
		sum += process_node(node)

		// Check if node is Expression (similar to the problematic code)
		if !is_last {
			match node {
				Expression { sum += 1 }
				Statement {}
			}
		}
	}

	// Check last element
	if c.body.len > 0 {
		match c.body[c.body.len - 1] {
			Statement { sum += 100 }
			Expression {}
		}
	}

	return sum
}

fn main() {
	// Create some nodes
	stmt := Statement(Foo{ value: 42, span: 1 })
	expr := Expression(Baz{ data: 'hello', span: 2 })

	// Create container with mixed nodes
	container := Container{
		body: [Node(stmt), Node(expr), Node(Statement(Bar{ name: 'test', span: 3 }))]
		span: 10
	}

	result := process_container(container)
	println('Result: ${result}')

	// Nested containers
	inner := Container{
		body: [Node(Statement(Foo{ value: 1, span: 5 }))]
		span: 20
	}

	outer := Container{
		body: [Node(Expression(inner)), Node(stmt)]
		span: 30
	}

	result2 := process_container(outer)
	println('Result2: ${result2}')
}
