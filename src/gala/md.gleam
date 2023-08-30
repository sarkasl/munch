import gleam/string
import gleam/list
import gleam/io
import gleam/string_builder.{StringBuilder}
import gleam/result.{then}
import gala/tree
import gala/parser.{is_grapheme, is_whitespace}

pub fn parse(markdown: String) -> Nil {
  markdown
  |> string.replace("\r\n", "\n")
  |> string.split("\n")
  |> collapse_blank_lines()
  |> block_parse()
  |> block_pretty_print()
}

// ####################################################################
// nodes ##############################################################

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

// ####################################################################
// prepare input ######################################################

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

// ####################################################################
// block ast ##########################################################

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

fn try_add(list: List(a), item_result: Result(a, Nil)) -> List(a) {
  case item_result {
    Ok(item) -> [item, ..list]
    Error(_) -> list
  }
}

fn try_create(item_result: Result(a, Nil)) -> List(a) {
  case item_result {
    Ok(item) -> [item]
    Error(_) -> []
  }
}

// ####################################################################
// block parsing ######################################################

type Openness {
  Open
  Closed
}

type Dirtiness {
  Dirty
  Clean
}

type BlockParserState {
  BlockParserState(tokens: List(String), open: Openness, dirty: Dirtiness)
}

fn parse_nodes(tokens: List(String)) -> Result(BlockNode, Nil) {
  case block_parser(tokens) {
    Ok(#(_, node)) -> Ok(node)
    Error(_) -> Error(Nil)
  }
}

fn append_container(
  container: BlockContainer,
  tokens: List(String),
) -> #(BlockContainer, List(String), Openness) {
  case container {
    DocumentBlock -> #(container, tokens, Open)
    BlockQuoteBlock -> {
      case parse_block_quote_cont(tokens) {
        Ok(tokens) -> #(container, tokens, Open)
        Error(_) -> #(container, tokens, Closed)
      }
    }
  }
}

fn append_leaf(leaf: BlockLeaf, tokens: List(String)) -> #(BlockLeaf, Dirtiness) {
  case leaf {
    HeadingBlock(..) -> #(leaf, Clean)
    ParagraphBlock(paragraph_tokens) -> {
      case parse_paragraph_cont(tokens) {
        Ok(paragraph_cont) -> #(
          ParagraphBlock(string_builder.append(paragraph_tokens, paragraph_cont)),
          Dirty,
        )
        Error(_) -> #(leaf, Clean)
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
          Container(block, try_create(parse_nodes(state.tokens))),
          BlockParserState(..state, dirty: Dirty),
        )

        Open, [Container(child_block, child_children), ..rest] -> {
          let #(child_block, tokens, open) =
            append_container(child_block, state.tokens)
          let child = Container(child_block, child_children)
          let state = BlockParserState(tokens, open, Clean)

          let #(child, state) = do_block_parse(child, state)
          case open, state.dirty {
            Closed, Clean -> #(
              Container(block, try_add([child, ..rest], parse_nodes(tokens))),
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
          let #(child_block, dirty) = append_leaf(child_block, state.tokens)
          case dirty {
            Clean ->
              case parse_nodes(state.tokens) {
                Error(_) -> #(node, state)
                Ok(new_child) -> #(
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
          let #(child_block, dirty) = append_leaf(child_block, state.tokens)
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
  let tokens = string.to_graphemes(line)
  do_block_parse(node, BlockParserState(tokens, Open, Clean)).0
}

fn block_parse(input: List(String)) -> BlockNode {
  input
  |> list.fold(Container(DocumentBlock, []), parse_line)
  |> block_invert()
}

// ####################################################################
// block text parsing #################################################

fn line_ending_parser(tokens: List(String)) -> parser.ParserReturn(Nil) {
  tokens
  |> parser.try_drop(parser.take_while(_, is_whitespace))
  |> parser.eof
}

fn strip_3_whitespace(tokens: List(String)) -> List(String) {
  case tokens {
    [" ", " ", " ", ..rest] -> rest
    [" ", " ", ..rest] -> rest
    [" ", ..rest] -> rest
    _ -> tokens
  }
}

// fn continuation_parser(tokens: List(String)) -> ParserReturn(Nil) {
//   case tokens {
//     [" ", ..rest] -> Ok(#(rest, Nil))
//     ["\t", ..rest] -> Ok(#([" ", " ", ..rest], Nil))
//     _ -> Error(Nil)
//   }
// }

fn quote_parser(tokens: List(String)) -> parser.ParserReturn(BlockNode) {
  let continuation =
    parser.one_of([parser.error(parser.eof), parser.ok(block_parser)])

  let wrapped_tokens =
    tokens
    |> strip_3_whitespace
    |> parser.take(">")

  use #(tokens, _) <- then(wrapped_tokens)

  // modify the next token after quote
  let tokens = case tokens {
    [" ", ..rest] -> rest
    ["\t", ..rest] -> [" ", " ", ..rest]
    _ -> tokens
  }

  use #(tokens, child_result) <- then(continuation(tokens))

  Ok(#(tokens, Container(BlockQuoteBlock, try_create(child_result))))
}

fn heading_ending_parser(tokens: List(String)) -> parser.ParserReturn(Nil) {
  use #(tokens, _) <- then(parser.take_while(tokens, is_whitespace))
  let tokens = parser.try_drop(tokens, parser.take_while(_, is_grapheme("#")))
  line_ending_parser(tokens)
}

fn heading_parser(tokens: List(String)) -> parser.ParserReturn(BlockNode) {
  let character_parser =
    parser.while(parser.one_of([
      parser.error(parser.eof),
      parser.error(heading_ending_parser),
      parser.ok(parser.any),
    ]))

  let tokens = strip_3_whitespace(tokens)
  use #(tokens, hashes) <- then(parser.take_up_to(tokens, is_grapheme("#"), 6))
  use #(tokens, _) <- then(parser.take_if(tokens, is_whitespace))

  let tokens = parser.try_drop(tokens, parser.take_while(_, is_whitespace))
  use #(tokens, heading_text) <- then(character_parser(tokens))

  Ok(#(
    tokens,
    Leaf(HeadingBlock(list.length(hashes), string.concat(heading_text))),
  ))
}

fn paragraph_parser(tokens: List(String)) -> parser.ParserReturn(BlockNode) {
  let text =
    tokens
    |> parser.try_drop(parser.take_while(_, is_whitespace))
    |> string.concat

  Ok(#([], Leaf(ParagraphBlock(string_builder.from_string(text)))))
}

fn block_parser(tokens: List(String)) -> parser.ParserReturn(BlockNode) {
  tokens
  |> parser.one_of([heading_parser, quote_parser, paragraph_parser])
}

fn parse_block_quote_cont(tokens: List(String)) -> Result(List(String), Nil) {
  todo
}

fn parse_paragraph_cont(tokens: List(String)) -> Result(String, Nil) {
  todo
}