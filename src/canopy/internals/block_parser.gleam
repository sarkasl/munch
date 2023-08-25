import gleam/string
import gleam/option.{None, Option, Some}
import gleam/string_builder.{StringBuilder}
import gleam/list
import nibble
import nibble/lexer
import canopy/internals/block_ast.{BlockContainer, BlockLeaf, BlockNode}
import canopy/ast.{Container, Leaf, maybe_add, maybe_create}

pub type Token {
  Quote
  Heading(Int)
  Text(String)
  Whitespace(Int)
  Newline
}

pub type TokenList =
  List(lexer.Token(Token))

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
              Whitespace(get_whitespace_length(lexeme) + adjustment),
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
      ">", " " -> lexer.Keep(Quote, WhitespaceMode(-1))
      ">", "\t" -> lexer.Keep(Quote, WhitespaceMode(-2))
      ">", _ -> lexer.Keep(Quote, NormalMode)
      _, _ -> lexer.NoMatch
    }
  }

  let heading_matcher = {
    use _, lexeme, lookahead <- lexer.custom

    case string.last(lexeme), lookahead {
      Ok("#"), " " ->
        lexer.Keep(Heading(string.length(lexeme)), WhitespaceMode(-1))
      Ok("#"), "\t" ->
        lexer.Keep(Heading(string.length(lexeme)), WhitespaceMode(-2))
      Ok("#"), "" -> lexer.Keep(Heading(string.length(lexeme)), NormalMode)
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
      "\n", " " | "\n", "\t" -> lexer.Keep(Newline, WhitespaceMode(0))
      "\n", _ -> lexer.Keep(Newline, NormalMode)
      _, _ -> lexer.NoMatch
    }
  }

  let text_matcher = {
    use _, lexeme, lookahead <- lexer.custom

    case lookahead {
      " " | "\t" -> lexer.Keep(Text(lexeme), WhitespaceMode(0))
      _ -> lexer.Keep(Text(lexeme), NormalMode)
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

pub fn lex(line: String) -> Result(TokenList, lexer.Error) {
  let lexers = lexer.advanced(lexers)
  lexer.run_advanced(line, NormalMode, lexers)
}

fn do_parse_nodes() -> nibble.Parser(BlockNode, Token, Nil) {
  todo
}

pub fn parse_nodes(text: TokenList) -> Option(BlockNode) {
  case nibble.run(text, do_parse_nodes()) {
    Ok(nodes) -> Some(nodes)
    Error(..) -> None
  }
}

fn do_parse_paragraph_cont(
  paragraph_text: StringBuilder,
) -> nibble.Parser(BlockLeaf, Token, Nil) {
  todo
}

pub fn parse_paragraph_cont(
  paragraph_text: StringBuilder,
  text: TokenList,
) -> Option(BlockLeaf) {
  nibble.run(text, do_parse_paragraph_cont(paragraph_text))
  |> option.from_result()
}

fn do_parse_block_quote_cont() -> nibble.Parser(lexer.Token(Token), Token, Nil) {
  todo
}

pub fn parse_block_quote_cont(text: TokenList) -> Option(TokenList) {
  case nibble.run(text, do_parse_block_quote_cont()) {
    Ok(token) -> Some(drop_until(text, token))
    Error(..) -> None
  }
}
