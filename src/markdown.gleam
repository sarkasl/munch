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
}

// IndentCode(text: StringBuilder)
// FencedCode(info: String, text: StringBuilder)
// ThematicBreak

type BlockNode =
  AstNode(BlockContainer, BlockLeaf)

type BlockParserState {
  Open(text: String)
  Closed(text: String)
}

type Dirtiness {
  Dirty
  Clean
}

fn trim_up_to_3(text: String) -> String {
  case text {
    "    " <> _ | " \t" <> _ | "  \t" <> _ | "   \t" <> _ -> text
    "   " <> rest -> rest
    "  " <> rest -> rest
    " " <> rest -> rest
    _ -> text
  }
}

fn maybe_add(list: List(a), maybe_item: Option(a)) -> List(a) {
  case maybe_item {
    Some(item) -> [item, ..list]
    None -> list
  }
}

fn maybe_create(maybe_item: Option(a)) -> List(a) {
  case maybe_item {
    Some(item) -> [item]
    None -> []
  }
}

fn format_heading(level: Int, text: String) -> BlockNode {
  todo

  Leaf(Heading(level, trimmed))
}

fn create_block(text: String) -> Option(BlockNode) {
  let stripped = trim_up_to_3(text)
  case stripped {
    "" -> None
    "> " <> rest | ">\t" <> rest ->
      Some(Container(BlockQuote, maybe_create(create_block(rest))))
    ">" <> rest -> Some(Container(BlockQuote, maybe_create(create_block(rest))))
    "# " <> rest | "#\t" <> rest -> Some(format_heading(1, rest))
    "## " <> rest | "##\t" <> rest -> Some(format_heading(2, rest))
    "### " <> rest | "###\t" <> rest -> Some(format_heading(3, rest))
    "#### " <> rest | "####\t" <> rest -> Some(format_heading(4, rest))
    "##### " <> rest | "#####\t" <> rest -> Some(format_heading(5, rest))
    "###### " <> rest | "######\t" <> rest -> Some(format_heading(6, rest))
    text -> Some(Leaf(Paragraph(string_builder.from_string(text))))
  }
}

fn eval_block(
  block: BlockContainer,
  state: BlockParserState,
) -> BlockParserState {
  let stripped = trim_up_to_3(state.text)
  case block {
    Document -> Open(state.text)
    BlockQuote ->
      case stripped {
        "> " <> rest | ">\t" <> rest -> Open(rest)
        ">" <> rest -> Open(rest)
        _ -> Closed(state.text)
      }
  }
}

fn append(block: BlockLeaf, text: String) -> #(BlockLeaf, Dirtiness) {
  case string.trim(text) {
    "" -> #(block, Clean)
    _ as trimmed -> {
      let stripped = trim_up_to_3(text)
      case block {
        Heading(..) -> #(block, Clean)
        Paragraph(text_builder) ->
          case stripped {
            ">" <> _ -> #(block, Clean)
            "#" <> _ -> #(block, Clean)
            _ -> #(
              Paragraph(string_builder.append(text_builder, "\n" <> trimmed)),
              Dirty,
            )
          }
      }
    }
  }
}

fn parse(node: BlockNode, state: BlockParserState) -> #(BlockNode, Dirtiness) {
  io.debug(state)
  node
  |> ast.invert()
  |> ast.repr()
  |> io.println()
  io.println("")

  case state, node {
    Open(text), Container(block, []) -> {
      #(Container(block, maybe_create(create_block(text))), Dirty)
    }
    Open(text) as state, Container(
      block,
      [Container(child_block, _) as child, ..rest],
    ) -> {
      case eval_block(child_block, state) {
        Open(..) as state -> {
          let #(child, dirty) = parse(child, state)
          #(Container(block, [child, ..rest]), dirty)
        }
        Closed(..) as state -> {
          let #(child, dirty) = parse(child, state)
          case dirty {
            Dirty -> #(Container(block, [child, ..rest]), Dirty)
            Clean -> #(
              Container(block, maybe_add([child, ..rest], create_block(text))),
              Dirty,
            )
          }
        }
      }
    }
    Closed(..), Container(_, []) as node -> {
      #(node, Clean)
    }
    Closed(..), Container(block, [Container(..) as child, ..rest]) -> {
      let #(child, dirty) = parse(child, state)
      #(Container(block, [child, ..rest]), dirty)
    }
    _ as state, Container(block, [Leaf(child_block) as child, ..rest]) as node -> {
      let #(child_block, append_dirty) = append(child_block, state.text)
      case state, append_dirty {
        Open(text), Clean ->
          case create_block(text) {
            None -> #(node, Clean)
            Some(new_child) -> #(
              Container(block, [new_child, child, ..rest]),
              Dirty,
            )
          }
        Closed(..), Clean -> #(node, Clean)
        _, Dirty -> #(Container(block, [Leaf(child_block), ..rest]), Dirty)
      }
    }
    _, Leaf(..) ->
      panic as "if this node is leaf something has gone horribly wrong"
  }
}

fn parse_line(node: BlockNode, line: String) -> BlockNode {
  parse(node, Open(line)).0
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
    string.trim(
      "
# foo#
",
    )

  input
  |> block_parse()
  |> ast.repr()
  |> io.println()
}
