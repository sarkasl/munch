import gleam/io
import gleam/string
import gleam/string_builder.{StringBuilder}
import gleam/option.{None, Option, Some}
import gleam/list
//import gleam/erlang

type BlockNode {
  Document
  Paragraph(text: StringBuilder)
  Heading(level: Int, text: StringBuilder)
}

type AstNode(a) {
  AstNode(value: a, children: List(AstNode(a)))
}

fn rec_repr(node: AstNode(a), indent: String) -> String {
  case node {
    AstNode(value, []) -> indent <> string.inspect(value)
    AstNode(value, children) -> {
      let children_indent = indent <> "  "
      children
      |> list.map(rec_repr(_, children_indent))
      |> list.prepend(indent <> string.inspect(value))
      |> string.join("\n")
    }
  }
}

fn repr(node: AstNode(a)) -> String {
  rec_repr(node, "")
}

fn left_strip(line: String) -> String {
  case line {
    "   " <> rest -> rest
    "  " <> rest -> rest
    " " <> rest -> rest
    _ -> line
  }
}

fn should_close_block(node: BlockNode, line: String) -> Bool {
  case node {
    Document -> False
    Paragraph(_) ->
      case line {
        "" -> True
        _ -> False
      }
    Heading(_, _) -> True
  }
}

fn open_block(line: String) -> Option(BlockNode) {
  // inneficient, called multiple times
  case string.trim(line) {
    "" -> None
    "# " <> text -> Some(Heading(1, string_builder.from_string(text)))
    "## " <> text -> Some(Heading(2, string_builder.from_string(text)))
    "### " <> text -> Some(Heading(3, string_builder.from_string(text)))
    "#### " <> text -> Some(Heading(4, string_builder.from_string(text)))
    "##### " <> text -> Some(Heading(5, string_builder.from_string(text)))
    "###### " <> text -> Some(Heading(6, string_builder.from_string(text)))
    text -> Some(Paragraph(string_builder.from_string(text)))
  }
}

fn parse_line(ast: AstNode(BlockNode), line: String) -> AstNode(BlockNode) {
  io.println(repr(ast))
  io.println("")
  case ast.children, ast.value {
    [], Paragraph(text) ->
      case string.trim(line) {
        "" -> ast
        line -> {
          let separated = string_builder.append(text, "\n")

          line
          |> string.trim_left()
          |> string_builder.append(separated, _)
          |> Paragraph()
          |> AstNode([])
        }
      }
    [], _ ->
      case open_block(line) {
        None -> ast
        Some(node) -> AstNode(ast.value, [AstNode(node, [])])
      }
    [], _ -> panic as "Bug in the parser!"
    [child, ..rest], _ ->
      case should_close_block(child.value, line) {
        True ->
          case open_block(line) {
            None -> AstNode(ast.value, [parse_line(child, line), ..rest])
            Some(node) -> AstNode(ast.value, [AstNode(node, []), child, ..rest])
          }
        False -> AstNode(ast.value, [parse_line(child, line), ..rest])
      }
  }
}

fn reverse(ast: AstNode(a)) -> AstNode(a) {
  case ast.children {
    [] -> ast
    children ->
      AstNode(
        ..ast,
        children: {
          children
          |> list.reverse()
          |> list.map(reverse)
        },
      )
  }
}

fn block_parse(input: String) -> AstNode(BlockNode) {
  input
  |> string.split("\n")
  |> list.map(string.trim_right)
  |> list.fold(AstNode(Document, []), parse_line)
  |> reverse()
}

pub fn main() {
  // let assert Ok(line) = erlang.get_line("")
  let input =
    "
  
# This is a heading

This is a paragraph
Continued

"
  input
  |> block_parse()
  |> repr()
  |> io.println()
}
