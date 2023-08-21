import gleam/string
import gleam/list
import gleam/option.{None, Option, Some}

pub type Node(a) {
  Node(value: a, children: List(Node(a)))
}

fn rec_repr(node: Node(a), indent: String) -> String {
  case node {
    Node(value, []) -> indent <> string.inspect(value)
    Node(value, children) -> {
      let children_indent = indent <> "  "
      children
      |> list.map(rec_repr(_, children_indent))
      |> list.prepend(indent <> string.inspect(value))
      |> string.join("\n")
    }
  }
}

pub fn repr(node: Node(a)) -> String {
  rec_repr(node, "")
}

pub fn invert(ast: Node(a)) -> Node(a) {
  case ast {
    Node(_, []) -> ast
    Node(value, children) ->
      Node(
        value: value,
        children: {
          children
          |> list.reverse()
          |> list.map(invert)
        },
      )
  }
}

pub type SplitNode(container, leaf) {
  Container(value: container, children: List(SplitNode(container, leaf)))
  Leaf(value: leaf)
}

fn rec_repr_split(node: SplitNode(a, b), indent: String) -> String {
  case node {
    Leaf(value) -> indent <> string.inspect(value)
    Container(value, []) -> indent <> string.inspect(value)
    Container(value, children) -> {
      let children_indent = indent <> "  "
      children
      |> list.map(rec_repr_split(_, children_indent))
      |> list.prepend(indent <> string.inspect(value))
      |> string.join("\n")
    }
  }
}

pub fn repr_split(node: SplitNode(a, b)) -> String {
  rec_repr_split(node, "")
}

pub fn invert_split(ast: SplitNode(a, b)) -> SplitNode(a, b) {
  case ast {
    Leaf(_) -> ast
    Container(_, []) -> ast
    Container(value, children) ->
      Container(
        value: value,
        children: {
          children
          |> list.reverse()
          |> list.map(invert_split)
        },
      )
  }
}

pub fn maybe_add_child(list: List(a), maybe_item: Option(a)) -> List(a) {
  case maybe_item {
    Some(item) -> [item, ..list]
    None -> list
  }
}

pub fn maybe_create_child(maybe_item: Option(a)) -> List(a) {
  case maybe_item {
    Some(item) -> [item]
    None -> []
  }
}
