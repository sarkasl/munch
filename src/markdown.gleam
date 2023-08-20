import gleam/io
import gleam/string
import gleam/string_builder.{StringBuilder}
import gleam/option.{None, Option, Some}
import gleam/list
import ast.{AstNode, Container, Leaf}

type BlockContainer {
  Document
  BlockQuote
}

// BulletList(bullet: String, justify: Int)
// OrderedList(start: Int, delimeter: String, justify: Int)
// ListItem

type BlockLeaf {
  Paragraph(text: StringBuilder)
  Heading(level: Int, text: String)
  Empty
}

// IndentCode(text: StringBuilder)
// FencedCode(info: String, text: StringBuilder)
// ThematicBreak

type BlockNode =
  AstNode(BlockContainer, BlockLeaf)

type BlockParserState {
  Open(blocks: String)
  Closing(blocks: String)
}

fn trim_up_to_3(blocks: String) -> String {
  case blocks {
    "    " <> _ -> blocks
    "   " <> rest -> rest
    "  " <> rest -> rest
    " " <> rest -> rest
    _ -> blocks
  }
}

fn parse_container(
  container: BlockContainer,
  blocks: String,
) -> BlockParserState {
  let normalized = string.replace(blocks, "\t", "    ")
  let stripped = trim_up_to_3(normalized)
  case container {
    Document -> Open(blocks)
    BlockQuote ->
      case stripped {
        "> " <> rest -> Open(rest)
        ">" <> rest -> Open(rest)
        _ -> Closing(blocks)
      }
  }
}

fn try_appending(value: BlockLeaf, blocks: String) -> Option(BlockLeaf) {
  case value {
    Heading(..) -> None
    Empty -> None
    Paragraph(text) ->
      case string.trim_left(blocks) {
        "" -> None
        new_text ->
          Some(Paragraph(string_builder.append(text, "\n" <> new_text)))
      }
  }
}

fn new_node(blocks: String) -> List(BlockNode) {
  let normalized = string.replace(blocks, "\t", "    ")
  let stripped = trim_up_to_3(normalized)
  case stripped {
    "" -> [Leaf(Empty)]
    "> " <> rest -> [Container(BlockQuote, new_node(rest))]
    ">" <> rest -> [Container(BlockQuote, new_node(rest))]
    "# " <> rest -> [Leaf(Heading(1, rest))]
    "## " <> rest -> [Leaf(Heading(2, rest))]
    "### " <> rest -> [Leaf(Heading(3, rest))]
    "#### " <> rest -> [Leaf(Heading(4, rest))]
    "##### " <> rest -> [Leaf(Heading(5, rest))]
    "###### " <> rest -> [Leaf(Heading(6, rest))]
    text -> {
      case string.trim(text) {
        "" -> []
        text -> [Leaf(Paragraph(string_builder.from_string(text)))]
      }
    }
  }
}

fn try_new_node(blocks: String) -> BlockNode {
  let assert [node] = new_node(blocks)
  node
}

fn parse(node: BlockNode, state: BlockParserState) -> #(List(BlockNode), Bool) {
  node
  |> ast.invert()
  |> ast.repr()
  |> io.println()
  io.println("")
  case node, state {
    Container(value, [child, ..rest]), Open(blocks) -> {
      let new_state = parse_container(value, blocks)
      let #(new_children, dirty) = parse(child, new_state)
      case new_state, dirty {
        _, True -> #(
          [Container(value, list.concat([new_children, rest]))],
          True,
        )
        Closing(..), False -> #([try_new_node(new_state.blocks), node], True)
        Open(..), False -> #([node], False)
      }
    }
    Container(value, []), Open(blocks) ->
      case parse_container(value, blocks) {
        Closing(..) -> #([try_new_node(blocks), node], True)
        Open(..) -> #([Container(value, [try_new_node(blocks)])], True)
      }
    Container(_, [child, ..]), Closing(..) -> parse(child, state)
    Container(_, []), Closing(..) -> #([node], False)
    Leaf(value), _ ->
      case try_appending(value, state.blocks) {
        None -> #([node], False)
        Some(new_node) -> #([Leaf(new_node)], True)
      }
  }
}

fn parse_line(node: BlockNode, line: String) -> BlockNode {
  let assert #([result], _) = parse(node, Open(line))
  result
}

fn block_parse(input: String) -> BlockNode {
  input
  |> string.split("\n")
  |> list.map(string.trim_right)
  |> list.fold(Container(Document, []), parse_line)
  |> ast.invert()
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
  |> ast.repr()
  |> io.println()
}
