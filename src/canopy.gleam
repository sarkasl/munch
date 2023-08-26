import gleam/string
import gleam/option.{None, Option, Some}
import gleam/list
import gleam/io
import gleam/string_builder.{StringBuilder}
import nibble
import nibble/lexer
import scratchpad

pub fn parse(markdown: String) -> BlockNode {
  markdown
  |> string.replace("\r\n", "\n")
  |> string.split("\n")
  |> collapse_blank_lines()
  |> block_parse()
}

pub fn main() {
  //   let input =
  //     string.trim(
  //       "
  // ## 
  // #
  // ### ###
  // ",
  //     )

  //   input
  //   |> parse()
  //   |> repr_split()
  //   |> io.println()
  scratchpad.main()
}

//############################################################################//
//                               Prepare input                                //
//############################################################################//

fn collapse_blank_lines(lines: List(String)) -> List(String) {
  lines
  |> list.fold([], do_collapse_blank_lines)
  |> list.reverse()
}

fn do_collapse_blank_lines(acc: List(String), line: String) -> List(String) {
  case string.length(string.trim_right(line)), acc {
    0, [last, ..rest] -> ["\n" <> last, ..rest]
    0, [] -> ["\n"]
    _, _ -> [line, ..acc]
  }
}

//############################################################################//
//                                    Ast                                     //
//############################################################################//

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

//############################################################################//
//                                 Block ast                                  //
//############################################################################//

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

type Openness {
  Open
  Closed
}

type Dirtiness {
  Dirty
  Clean
}

type BlockParserState {
  BlockParserState(text: BlockTokenList, open: Openness, dirty: Dirtiness)
}

fn append_container(
  container: BlockContainer,
  text: BlockTokenList,
) -> #(BlockContainer, BlockTokenList, Openness) {
  case container {
    Document -> #(container, text, Open)
    BlockQuote -> {
      case parse_block_quote_cont(text) {
        Some(text) -> #(container, text, Open)
        None -> #(container, text, Closed)
      }
    }
  }
}

fn append_leaf(leaf: BlockLeaf, text: BlockTokenList) -> #(BlockLeaf, Dirtiness) {
  case leaf {
    Heading(..) -> #(leaf, Clean)
    Paragraph(paragraph_text) -> {
      case parse_paragraph_cont(paragraph_text, text) {
        Some(paragraph) -> #(paragraph, Dirty)
        None -> #(leaf, Clean)
      }
    }
  }
}

fn rec_parse(
  node: BlockNode,
  state: BlockParserState,
) -> #(BlockNode, BlockParserState) {
  case node {
    Container(block, children) ->
      case state.open, children {
        Open, [] -> #(
          Container(block, maybe_create(parse_nodes(state.text))),
          BlockParserState(..state, dirty: Dirty),
        )

        Open, [Container(child_block, child_children), ..rest] -> {
          let #(child_block, text, open) =
            append_container(child_block, state.text)
          let child = Container(child_block, child_children)
          let state = BlockParserState(text, open, Clean)

          let #(child, state) = rec_parse(child, state)
          case open, state.dirty {
            Closed, Clean -> #(
              Container(block, maybe_add([child, ..rest], parse_nodes(text))),
              BlockParserState(..state, dirty: Dirty),
            )
            Open, Clean -> #(node, state)
            _, _ -> #(Container(block, [child, ..rest]), state)
          }
        }

        Closed, [] -> #(node, state)

        Closed, [Container(..) as child, ..rest] -> {
          let #(child, state) = rec_parse(child, state)
          case state.dirty {
            Clean -> #(node, state)
            Dirty -> #(Container(block, [child, ..rest]), state)
          }
        }

        Open, [Leaf(child_block) as child, ..rest] -> {
          let #(child_block, dirty) = append_leaf(child_block, state.text)
          case dirty {
            Clean ->
              case parse_nodes(state.text) {
                None -> #(node, state)
                Some(new_child) -> #(
                  Container(block, [new_child, child, ..rest]),
                  BlockParserState(..state, dirty: Dirty),
                )
              }
            Dirty -> #(
              Container(block, [Leaf(child_block), ..rest]),
              BlockParserState(..state, dirty: Dirty),
            )
          }
        }

        Closed, [Leaf(child_block), ..rest] -> {
          let #(child_block, dirty) = append_leaf(child_block, state.text)
          case dirty {
            Clean -> #(node, state)
            Dirty -> #(
              Container(block, [Leaf(child_block), ..rest]),
              BlockParserState(..state, dirty: Dirty),
            )
          }
        }
      }

    Leaf(..) ->
      panic as "if this node is leaf something has gone horribly wrong"
  }
}

fn parse_line(node: BlockNode, line: String) -> BlockNode {
  let assert Ok(tokens) = lex(line)
  rec_parse(node, BlockParserState(tokens, Open, Clean)).0
}

pub fn block_parse(input: List(String)) -> BlockNode {
  input
  |> list.fold(Container(Document, []), parse_line)
  |> invert_split()
}

//############################################################################//
//                               Block parsing                                //
//############################################################################//

pub type BlockToken {
  QuoteT
  HeadingT(Int)
  TextT(String)
  WhitespaceT(Int)
  NewlineT
}

pub type BlockTokenList =
  List(lexer.Token(BlockToken))

type MatcherMode {
  NormalMode
  WhitespaceMode(Int)
}

fn get_whitespace_length(whitespace: String) -> Int {
  whitespace
  |> string.replace("\t", "    ")
  |> string.length()
}

fn drop_until(in list: List(a), until item: a) -> List(a) {
  use list_item <- list.drop_while(list)
  list_item != item
}

fn lexers(_) {
  let whitespace_matcher = {
    use mode, lexeme, lookahead <- lexer.custom

    case mode {
      WhitespaceMode(adjustment) ->
        case string.last(lexeme), lookahead {
          Ok(" "), " " | Ok(" "), "\t" -> lexer.Skip
          Ok("\t"), " " | Ok("\t"), "\t" -> lexer.Skip
          Ok(" "), _ | Ok("\t"), _ ->
            lexer.Keep(
              WhitespaceT(get_whitespace_length(lexeme) + adjustment),
              NormalMode,
            )
          _, _ -> lexer.NoMatch
        }
      _ -> lexer.NoMatch
    }
  }

  let quote_matcher = {
    use _, lexeme, lookahead <- lexer.custom

    case lexeme, lookahead {
      ">", " " -> lexer.Keep(QuoteT, WhitespaceMode(-1))
      ">", "\t" -> lexer.Keep(QuoteT, WhitespaceMode(-2))
      ">", _ -> lexer.Keep(QuoteT, NormalMode)
      _, _ -> lexer.NoMatch
    }
  }

  let heading_matcher = {
    use _, lexeme, lookahead <- lexer.custom

    case string.last(lexeme), lookahead {
      Ok("#"), " " ->
        lexer.Keep(HeadingT(string.length(lexeme)), WhitespaceMode(-1))
      Ok("#"), "\t" ->
        lexer.Keep(HeadingT(string.length(lexeme)), WhitespaceMode(-2))
      Ok("#"), "" -> lexer.Keep(HeadingT(string.length(lexeme)), NormalMode)
      Ok("#"), "#" -> lexer.Skip
      _, _ -> lexer.NoMatch
    }
  }

  let start_matcher = {
    use _, lexeme, lookahead <- lexer.custom

    case lexeme, lookahead {
      "", " " | "", "\t" -> lexer.Drop(WhitespaceMode(0))
      "", _ -> lexer.Drop(NormalMode)
      _, _ -> lexer.NoMatch
    }
  }

  let new_line_matcher = {
    use _, lexeme, lookahead <- lexer.custom

    case lexeme, lookahead {
      "\n", " " | "\n", "\t" -> lexer.Keep(NewlineT, WhitespaceMode(0))
      "\n", _ -> lexer.Keep(NewlineT, NormalMode)
      _, _ -> lexer.NoMatch
    }
  }

  let text_matcher = {
    use _, lexeme, lookahead <- lexer.custom

    case lookahead {
      " " | "\t" -> lexer.Keep(TextT(lexeme), WhitespaceMode(0))
      _ -> lexer.Keep(TextT(lexeme), NormalMode)
    }
  }

  [
    whitespace_matcher,
    quote_matcher,
    heading_matcher,
    new_line_matcher,
    start_matcher,
    text_matcher,
  ]
}

pub fn lex(line: String) -> Result(BlockTokenList, lexer.Error) {
  let lexers = lexer.advanced(lexers)
  lexer.run_advanced(line, NormalMode, lexers)
}

fn do_parse_nodes() -> nibble.Parser(BlockNode, BlockToken, Nil) {
  todo
}

pub fn parse_nodes(text: BlockTokenList) -> Option(BlockNode) {
  case nibble.run(text, do_parse_nodes()) {
    Ok(nodes) -> Some(nodes)
    Error(..) -> None
  }
}

fn do_parse_paragraph_cont(
  paragraph_text: StringBuilder,
) -> nibble.Parser(BlockLeaf, BlockToken, Nil) {
  todo
}

pub fn parse_paragraph_cont(
  paragraph_text: StringBuilder,
  text: BlockTokenList,
) -> Option(BlockLeaf) {
  nibble.run(text, do_parse_paragraph_cont(paragraph_text))
  |> option.from_result()
}

fn do_parse_block_quote_cont() -> nibble.Parser(
  lexer.Token(BlockToken),
  BlockToken,
  Nil,
) {
  todo
}

pub fn parse_block_quote_cont(text: BlockTokenList) -> Option(BlockTokenList) {
  case nibble.run(text, do_parse_block_quote_cont()) {
    Ok(token) -> Some(drop_until(text, token))
    Error(..) -> None
  }
}
