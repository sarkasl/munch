import gleam/string
import gleam/string_builder.{StringBuilder}
import gleam/option.{None, Option, Some}
import gleam/list
import gleam/regex.{Regex}
import canopy/ast.{Container, Leaf, SplitNode, maybe_add, maybe_create}
import nibble/lexer.{Error}

pub type BlockContainer {
  Document
  BlockQuote
}

// BulletList(bullet: String, justify: Int)
// OrderedList(start: Int, delimeter: String, justify: Int)
// ListItem

pub type BlockLeaf {
  Paragraph(text: StringBuilder)
  Heading(level: Int, text: String)
}

// IndentCode(text: StringBuilder)
// FencedCode(info: String, text: StringBuilder)
// ThematicBreak

pub type BlockNode =
  SplitNode(BlockContainer, BlockLeaf)

type BlockParserState {
  Open(text: String)
  Closed(text: String)
}

type Dirtiness {
  Dirty
  Clean
}

type ReParser {
  ReParser(
    re: Regex,
    parser: fn(List(Option(String)), fn(String) -> Option(BlockNode)) ->
      Option(BlockNode),
  )
}

type Re {
  Re(empty: ReParser, quote: ReParser)
}

fn parse_empty(
  _captures: List(Option(String)),
  _continue: fn(String) -> Option(BlockNode),
) -> Option(BlockNode) {
  None
}

fn parse_block_quote(
  captures: List(Option(String)),
  continue: fn(String) -> Option(BlockNode),
) -> Option(BlockNode) {
  case captures {
    [Some(rest)] -> Some(Container(BlockQuote, maybe_create(continue(rest))))
    [None] -> Some(Container(BlockQuote, []))
  }
}

fn parse_heading(
  captures: List(Option(String)),
  continue: fn(String) -> Option(BlockNode),
) -> Option(BlockNode) {
  todo
}

fn re_get(expression: String) -> Regex {
  case regex.from_string(expression) {
    Ok(value) -> value
    Error(..) -> panic
  }
}

fn get_regex() -> Re {
  Re(
    empty: ReParser(re_get("^$"), parse_empty),
    quote: ReParser(re_get("^ {0,3}>[ \t]?(.*)"), parse_block_quote),
  )
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

fn format_heading(level: Int, text: String) -> BlockNode {
  let trimmed = string.trim_left(text)
  let split_suffix =
    trimmed
    |> string.reverse()
    |> string.split_once(" ")

  let #(suffix, reversed_name) = case split_suffix {
    Ok(value) -> value
    Error(..) -> #(trimmed, "")
  }

  let hash_only_suffix =
    suffix
    |> string.replace("#", "")
    |> string.is_empty()

  case hash_only_suffix {
    False -> Leaf(Heading(level, trimmed))
    True ->
      Leaf(Heading(
        level,
        reversed_name
        |> string.reverse()
        |> string.trim_right(),
      ))
  }
}

fn create_block(text: String) -> Option(BlockNode) {
  let stripped = trim_up_to_3(text)
  case stripped {
    "" -> None
    // block quotes
    "> " <> rest | ">\t" <> rest -> {
      Some(Container(BlockQuote, maybe_create(create_block(rest))))
    }
    ">" <> rest -> {
      Some(Container(BlockQuote, maybe_create(create_block(rest))))
    }
    // headings
    "#" -> Some(Leaf(Heading(1, "")))
    "##" -> Some(Leaf(Heading(2, "")))
    "###" -> Some(Leaf(Heading(3, "")))
    "####" -> Some(Leaf(Heading(4, "")))
    "#####" -> Some(Leaf(Heading(5, "")))
    "######" -> Some(Leaf(Heading(6, "")))
    "# " <> rest | "#\t" <> rest -> Some(format_heading(1, rest))
    "## " <> rest | "##\t" <> rest -> Some(format_heading(2, rest))
    "### " <> rest | "###\t" <> rest -> Some(format_heading(3, rest))
    "#### " <> rest | "####\t" <> rest -> Some(format_heading(4, rest))
    "##### " <> rest | "#####\t" <> rest -> Some(format_heading(5, rest))
    "###### " <> rest | "######\t" <> rest -> Some(format_heading(6, rest))
    // paragraphs
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

fn rec_parse(
  node: BlockNode,
  state: BlockParserState,
) -> #(BlockNode, Dirtiness) {
  case state, node {
    // open, container with no children
    Open(text), Container(block, []) -> {
      #(Container(block, maybe_create(create_block(text))), Dirty)
    }
    // open, container with children
    Open(text) as state, Container(
      block,
      [Container(child_block, _) as child, ..rest],
    ) -> {
      case eval_block(child_block, state) {
        Open(..) as new_state -> {
          let #(child, dirty) = rec_parse(child, new_state)
          #(Container(block, [child, ..rest]), dirty)
        }
        Closed(..) as new_state -> {
          let #(child, dirty) = rec_parse(child, new_state)
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
    // closed, container with no children
    Closed(..), Container(_, []) as node -> {
      #(node, Clean)
    }
    // closed, container with children
    Closed(..), Container(block, [Container(..) as child, ..rest]) as node -> {
      let #(child, dirty) = rec_parse(child, state)
      case dirty {
        Clean -> #(node, Clean)
        Dirty -> #(Container(block, [child, ..rest]), Dirty)
      }
    }
    // open, container with leaf child
    Open(text), Container(block, [Leaf(child_block) as child, ..rest]) as node -> {
      let #(child_block, append_dirty) = append(child_block, text)
      case append_dirty {
        Clean ->
          case create_block(text) {
            None -> #(node, Clean)
            Some(new_child) -> #(
              Container(block, [new_child, child, ..rest]),
              Dirty,
            )
          }
        Dirty -> #(Container(block, [Leaf(child_block), ..rest]), Dirty)
      }
    }
    // closed, container with leaf child
    Closed(text), Container(block, [Leaf(child_block), ..rest]) as node -> {
      let #(child_block, append_dirty) = append(child_block, text)
      case append_dirty {
        Clean -> #(node, Clean)
        Dirty -> #(Container(block, [Leaf(child_block), ..rest]), Dirty)
      }
    }
    // unreachable
    _, Leaf(..) ->
      panic as "if this node is leaf something has gone horribly wrong"
  }
}

fn parse_line(node: BlockNode, line: String) -> BlockNode {
  rec_parse(node, Open(line)).0
}

pub fn parse(input: String) -> BlockNode {
  let _re = get_regex()

  input
  |> string.split("\n")
  |> list.map(string.trim_right)
  |> list.fold(Container(Document, []), parse_line)
  |> ast.invert_split()
}
