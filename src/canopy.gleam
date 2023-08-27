import gleam/string
import gleam/option.{None, Option, Some}
import gleam/list
import gleam/io
import gleam/string_builder.{StringBuilder}
import nibble
import nibble/lexer
import canopy/tree

pub fn parse(markdown: String) -> tree.Node(MarkdownNode) {
  markdown
  |> string.replace("\r\n", "\n")
  |> string.split("\n")
  |> collapse_blank_lines()
  |> block_parse()
  todo
}

pub fn main() {
  let input =
    string.trim(
      "
  ## 
  #
  ### ###
  ",
    )

  input
  |> string.replace("\r\n", "\n")
  |> string.split("\n")
  |> collapse_blank_lines()
  |> block_parse()
  |> block_pretty_print()
}

//############################################################################//
//                                   Nodes                                    //
//############################################################################//

pub type MarkdownElement {
  Document
  ThematicBreak
  Heading(level: Int)
  SetextHeading
  CodeBlock(info: String, text: String)
  HtmlBlock(text: String)
  Paragraph
  BlockQuote
  Table
  TableHeader
  TableRow
  UnorderedList(tight: Bool)
  OrderedList(start: Int, tight: Bool)
  ListItem
  TaskList(tight: Bool)
  TaskItem(checked: Bool)
  Text(text: String)
  CodeSpan(text: String)
  Emphasis
  StrongEmphasis
  StrikeThrough
  Link
  Image
  Softbreak
  Hardbreak
}

pub type MarkdownNode =
  tree.Node(MarkdownElement)

//############################################################################//
//                               Prepare Input                                //
//############################################################################//

fn do_collapse_blank_lines(acc: List(String), line: String) -> List(String) {
  case string.length(string.trim_right(line)), acc {
    0, [last, ..rest] -> ["\n" <> last, ..rest]
    0, [] -> ["\n"]
    _, _ -> [line, ..acc]
  }
}

fn collapse_blank_lines(lines: List(String)) -> List(String) {
  lines
  |> list.fold([], do_collapse_blank_lines)
  |> list.reverse()
}

//############################################################################//
//                                 Block Ast                                  //
//############################################################################//

type BlockContainer {
  DocumentBlock
  BlockQuoteBlock
}

// BulletListBlock(bullet: String, justify: Int)
// OrderedListBlock(start: Int, delimeter: String, justify: Int)
// ListItemBlock

type BlockLeaf {
  ParagraphBlock(text: StringBuilder)
  HeadingBlock(level: Int, text: String)
}

// IndentCodeBlock(text: StringBuilder)
// FencedCodeBlock(info: String, text: StringBuilder)
// ThematicBreakB

type BlockNode {
  Container(value: BlockContainer, children: List(BlockNode))
  Leaf(value: BlockLeaf)
}

fn do_block_pretty_print(node: BlockNode, indent: String) -> String {
  case node {
    Leaf(value) -> indent <> string.inspect(value)
    Container(value, []) -> indent <> string.inspect(value)
    Container(value, children) -> {
      let children_indent = indent <> "  "
      children
      |> list.map(do_block_pretty_print(_, children_indent))
      |> list.prepend(indent <> string.inspect(value))
      |> string.join("\n")
    }
  }
}

fn block_pretty_print(node: BlockNode) -> Nil {
  do_block_pretty_print(node, "")
  |> io.println()
}

fn block_invert(ast: BlockNode) -> BlockNode {
  case ast {
    Leaf(_) -> ast
    Container(_, []) -> ast
    Container(value, children) ->
      Container(
        value: value,
        children: {
          children
          |> list.reverse()
          |> list.map(block_invert)
        },
      )
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

//############################################################################//
//                               Block Parsing                                //
//############################################################################//

type Openness {
  Open
  Closed
}

type Dirtiness {
  Dirty
  Clean
}

type BlockParserState {
  BlockParserState(text: List(BlockToken), open: Openness, dirty: Dirtiness)
}

fn block_parse(input: List(String)) -> BlockNode {
  input
  |> list.fold(Container(DocumentBlock, []), parse_line)
  |> block_invert()
}

fn parse_line(node: BlockNode, line: String) -> BlockNode {
  let assert Ok(tokens) = lex(line)
  do_block_parse(node, BlockParserState(tokens, Open, Clean)).0
}

fn parse_nodes(text: List(BlockToken)) -> Option(BlockNode) {
  case nibble.run(text, do_parse_nodes()) {
    Ok(nodes) -> Some(nodes)
    Error(..) -> None
  }
}

fn append_container(
  container: BlockContainer,
  text: List(BlockToken),
) -> #(BlockContainer, List(BlockToken), Openness) {
  case container {
    DocumentBlock -> #(container, text, Open)
    BlockQuoteBlock -> {
      case parse_block_quote_cont(text) {
        Some(text) -> #(container, text, Open)
        None -> #(container, text, Closed)
      }
    }
  }
}

fn append_leaf(
  leaf: BlockLeaf,
  text: List(BlockToken),
) -> #(BlockLeaf, Dirtiness) {
  case leaf {
    HeadingBlock(..) -> #(leaf, Clean)
    ParagraphBlock(paragraph_text) -> {
      case nibble.run(text, do_parse_paragraph_cont(paragraph_text)) {
        Ok(paragraph) -> #(paragraph, Dirty)
        Error(..) -> #(leaf, Clean)
      }
    }
  }
}

fn do_block_parse(
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

          let #(child, state) = do_block_parse(child, state)
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
          let #(child, state) = do_block_parse(child, state)
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

//############################################################################//
//                             Block Text Parsing                             //
//############################################################################//

type BlockT {
  QuoteToken
  HeadingToken(Int)
  TextToken(String)
  WhitespaceToken(Int)
  NewlineToken
}

type BlockToken =
  lexer.Token(BlockT)

type MatcherMode {
  NormalMode
  WhitespaceMode(Int)
}

fn lex(line: String) -> Result(List(BlockToken), lexer.Error) {
  let lexers = lexer.advanced(lexers)
  lexer.run_advanced(line, NormalMode, lexers)
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
              WhitespaceToken(get_whitespace_length(lexeme) + adjustment),
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
      ">", " " -> lexer.Keep(QuoteToken, WhitespaceMode(-1))
      ">", "\t" -> lexer.Keep(QuoteToken, WhitespaceMode(-2))
      ">", _ -> lexer.Keep(QuoteToken, NormalMode)
      _, _ -> lexer.NoMatch
    }
  }

  let heading_matcher = {
    use _, lexeme, lookahead <- lexer.custom

    case string.last(lexeme), lookahead {
      Ok("#"), " " ->
        lexer.Keep(HeadingToken(string.length(lexeme)), WhitespaceMode(-1))
      Ok("#"), "\t" ->
        lexer.Keep(HeadingToken(string.length(lexeme)), WhitespaceMode(-2))
      Ok("#"), "" -> lexer.Keep(HeadingToken(string.length(lexeme)), NormalMode)
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
      "\n", " " | "\n", "\t" -> lexer.Keep(NewlineToken, WhitespaceMode(0))
      "\n", _ -> lexer.Keep(NewlineToken, NormalMode)
      _, _ -> lexer.NoMatch
    }
  }

  let text_matcher = {
    use _, lexeme, lookahead <- lexer.custom

    case lookahead {
      " " | "\t" -> lexer.Keep(TextToken(lexeme), WhitespaceMode(0))
      _ -> lexer.Keep(TextToken(lexeme), NormalMode)
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

fn do_parse_nodes() -> nibble.Parser(BlockNode, BlockT, Nil) {
  todo
}

fn do_parse_paragraph_cont(
  paragraph_text: StringBuilder,
) -> nibble.Parser(BlockLeaf, BlockT, Nil) {
  todo
}

fn do_parse_block_quote_cont() -> nibble.Parser(BlockToken, BlockT, Nil) {
  todo
}

fn parse_block_quote_cont(text: List(BlockToken)) -> Option(List(BlockToken)) {
  case nibble.run(text, do_parse_block_quote_cont()) {
    Ok(token) -> Some(drop_until(text, token))
    Error(..) -> None
  }
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
