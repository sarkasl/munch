import gleam/io
import gleam/string
import gleam/list
import gleam/int
import gleam/result.{then}

// ####################################################################
// core ###############################################################

pub type ParserReturn(a) =
  Result(#(List(String), a), Nil)

pub type Parser(a) =
  fn(List(String)) -> ParserReturn(a)

pub fn drop(
  over tokens: List(String),
  from parser: Parser(a),
) -> Result(List(String), Nil) {
  case parser(tokens) {
    Ok(#(tokens, _)) -> Ok(tokens)
    Error(_) -> Error(Nil)
  }
}

pub fn try(
  over tokens: List(String),
  from parser: Parser(a),
) -> #(List(String), Result(a, Nil)) {
  case parser(tokens) {
    Ok(#(tokens, token)) -> #(tokens, Ok(token))
    Error(_) -> #(tokens, Error(Nil))
  }
}

pub fn try_drop(
  over tokens: List(String),
  from parser: Parser(a),
) -> List(String) {
  case parser(tokens) {
    Ok(#(tokens, _)) -> tokens
    Error(_) -> tokens
  }
}

pub fn map(from parser: Parser(a), with fun: fn(a) -> b) -> Parser(b) {
  fn(tokens) {
    case parser(tokens) {
      Ok(#(tokens, token)) -> Ok(#(tokens, fun(token)))
      Error(_) -> Error(Nil)
    }
  }
}

pub fn replace(from parser: Parser(a), with with: b) -> Parser(b) {
  fn(tokens) {
    case parser(tokens) {
      Ok(#(tokens, _)) -> Ok(#(tokens, with))
      Error(_) -> Error(Nil)
    }
  }
}

pub fn ok(from parser: Parser(a)) -> Parser(Result(a, Nil)) {
  fn(tokens) {
    case parser(tokens) {
      Ok(#(tokens, res)) -> Ok(#(tokens, Ok(res)))
      Error(_) -> Error(Nil)
    }
  }
}

pub fn error(from parser: Parser(a)) -> Parser(Result(b, Nil)) {
  fn(tokens) {
    case parser(tokens) {
      Ok(#(tokens, _)) -> Ok(#(tokens, Error(Nil)))
      Error(_) -> Error(Nil)
    }
  }
}

pub fn one_of(from parsers: List(Parser(a))) -> Parser(a) {
  fn(tokens) { list.find_map(parsers, fn(parser) { parser(tokens) }) }
}

fn do_while(
  tokens: List(String),
  parser: Parser(Result(a, Nil)),
) -> ParserReturn(List(a)) {
  case parser(tokens) {
    Ok(#(tokens, token_result)) ->
      case token_result {
        Ok(token) -> {
          use #(tokens, matched) <- then(do_while(tokens, parser))
          Ok(#(tokens, [token, ..matched]))
        }
        Error(_) -> Ok(#(tokens, []))
      }
    Error(_) -> Error(Nil)
  }
}

pub fn while(with parser: Parser(Result(a, Nil))) -> Parser(List(a)) {
  fn(tokens) { do_while(tokens, parser) }
}

// ####################################################################
// basics #############################################################

pub fn eof(tokens: List(String)) -> ParserReturn(Nil) {
  case tokens {
    [] -> Ok(#(tokens, Nil))
    _ -> Error(Nil)
  }
}

pub fn any(tokens: List(String)) -> ParserReturn(String) {
  case tokens {
    [token, ..rest] -> Ok(#(rest, token))
    _ -> Error(Nil)
  }
}

pub fn take(
  from tokens: List(String),
  what grapheme: String,
) -> ParserReturn(String) {
  case tokens {
    [token, ..rest] if token == grapheme -> Ok(#(rest, grapheme))
    _ -> Error(Nil)
  }
}

pub fn take_if(
  from tokens: List(String),
  with predicate: fn(String) -> Bool,
) -> ParserReturn(String) {
  case tokens {
    [token, ..rest] ->
      case predicate(token) {
        True -> Ok(#(rest, token))
        False -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn do_take_up_to(
  tokens: List(String),
  acc: List(String),
  predicate: fn(String) -> Bool,
  remaining: Int,
) -> #(List(String), List(String)) {
  case remaining, tokens {
    0, _ -> #(tokens, list.reverse(acc))
    _, [token, ..rest] ->
      case predicate(token) {
        True -> do_take_up_to(rest, [token, ..acc], predicate, remaining - 1)
        False -> #(tokens, list.reverse(acc))
      }
    _, _ -> #(tokens, list.reverse(acc))
  }
}

pub fn take_up_to(
  from tokens: List(String),
  with predicate: fn(String) -> Bool,
  up_to n: Int,
) -> ParserReturn(List(String)) {
  case do_take_up_to(tokens, [], predicate, n) {
    #(_, []) -> Error(Nil)
    _ as res -> Ok(res)
  }
}

pub fn take_while(
  from tokens: List(String),
  with predicate: fn(String) -> Bool,
) -> ParserReturn(List(String)) {
  case list.split_while(tokens, predicate) {
    #([], _) -> Error(Nil)
    #(matched, tokens) -> Ok(#(tokens, matched))
  }
}

// ####################################################################
// predicates #########################################################

pub fn is_number(token: String) -> Bool {
  case token {
    "0" | "1" | "2" | "3" | "4" -> True
    "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

pub fn is_whitespace(token: String) -> Bool {
  case token {
    " " | "\t" -> True
    _ -> False
  }
}

pub fn is_grapheme(grapheme: String) -> fn(String) -> Bool {
  fn(token) { token == grapheme }
}

// ####################################################################
// parsers ############################################################

pub fn int(tokens: List(String)) -> ParserReturn(Int) {
  use #(tokens, digits) <- then(take_while(tokens, is_number))
  use parsed <- result.map(int.parse(string.concat(digits)))
  #(tokens, parsed)
}
