import gleam/string
import gleam/list
import gleam/io
import gleam/option.{None, Option, Some}
import gleam/int

pub type Node(a) {
  Node(value: a, children: List(Node(a)))
}

pub fn map(over node: Node(a), with fun: fn(a) -> b) -> Node(b) {
  let value = fun(node.value)
  let children = list.map(node.children, map(_, fun))
  Node(value, children)
}

pub fn fold(
  over node: Node(a),
  from initial: acc,
  with fun: fn(acc, a) -> acc,
) -> acc {
  let acc = fun(initial, node.value)
  list.fold(node.children, acc, fn(acc, child) { fold(child, acc, fun) })
}

fn do_pretty_print(node: Node(a), indent: String) -> String {
  case node {
    Node(value, []) -> indent <> string.inspect(value)
    Node(value, children) -> {
      let children_indent = indent <> "  "
      children
      |> list.map(do_pretty_print(_, children_indent))
      |> list.prepend(indent <> string.inspect(value))
      |> string.join("\n")
    }
  }
}

pub fn pretty_print(node: Node(a)) -> Nil {
  do_pretty_print(node, "")
  |> io.println()
}

pub fn reverse(node: Node(a)) -> Node(a) {
  case node {
    Node(_, []) -> node
    Node(value, children) ->
      Node(
        value: value,
        children: {
          children
          |> list.reverse()
          |> list.map(reverse)
        },
      )
  }
}

pub fn maybe_add(list: List(a), maybe_item: Option(a)) -> List(a) {
  case maybe_item {
    Some(item) -> [item, ..list]
    None -> list
  }
}

pub fn maybe_create(maybe_item: Option(a)) -> List(a) {
  case maybe_item {
    Some(item) -> [item]
    None -> []
  }
}
