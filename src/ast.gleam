import gleam/string
import gleam/list

pub type AstNode(container, leaf) {
  Container(value: container, children: List(AstNode(container, leaf)))
  Leaf(value: leaf)
}

fn rec_repr(node: AstNode(a, b), indent: String) -> String {
  case node {
    Leaf(value) -> indent <> string.inspect(value)
    Container(value, []) -> indent <> string.inspect(value)
    Container(value, children) -> {
      let children_indent = indent <> "  "
      children
      |> list.map(rec_repr(_, children_indent))
      |> list.prepend(indent <> string.inspect(value))
      |> string.join("\n")
    }
  }
}

pub fn repr(node: AstNode(a, b)) -> String {
  rec_repr(node, "")
}

pub fn invert(ast: AstNode(a, b)) -> AstNode(a, b) {
  case ast {
    Leaf(_) -> ast
    Container(_, []) -> ast
    Container(value, children) ->
      Container(
        value: value,
        children: {
          children
          |> list.reverse()
          |> list.map(invert)
        },
      )
  }
}
