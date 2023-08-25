import gleam/string
import gleam/bit_string
import gleam/string_builder.{StringBuilder}
import gleam/option.{None, Option, Some}
import gleam/list
import gleam/regex.{Regex}
import canopy/ast.{Container, Leaf, SplitNode, maybe_add, maybe_create}
import canopy/internals/block_ast.{BlockContainer, BlockLeaf, BlockNode}
import canopy/internals/block_parser.{TokenList}

type Openness {
  Open
  Closed
}

type Dirtiness {
  Dirty
  Clean
}

type BlockParserState {
  BlockParserState(text: TokenList, open: Openness, dirty: Dirtiness)
}

fn append_container(
  container: BlockContainer,
  text: TokenList,
) -> #(BlockContainer, TokenList, Openness) {
  todo
}

fn append_leaf(leaf: BlockLeaf, text: TokenList) -> #(BlockLeaf, Dirtiness) {
  todo
}

fn create_blocks(text: TokenList) -> Option(BlockNode) {
  todo
}

fn rec_parse(
  node: BlockNode,
  state: BlockParserState,
) -> #(BlockNode, BlockParserState) {
  case node {
    Container(block, children) ->
      case state.open, children {
        Open, [] -> #(
          Container(block, maybe_create(create_blocks(state.text))),
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
              Container(block, maybe_add([child, ..rest], create_blocks(text))),
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
              case create_blocks(state.text) {
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
  let assert Ok(tokens) = block_parser.lex(line)
  rec_parse(node, BlockParserState(tokens, Open, Clean)).0
}

fn collapse_blank_lines(acc: List(String), line: String) -> List(String) {
  case string.length(string.trim_right(line)), acc {
    0, [last, ..rest] -> ["\n" <> last, ..rest]
    0, [] -> ["\n"]
    _, _ -> [line, ..acc]
  }
}

pub fn parse(input: String) -> BlockNode {
  input
  |> string.replace("\r\n", "\n")
  |> string.split("\n")
  |> list.fold([], collapse_blank_lines)
  |> list.reverse()
  |> list.fold(Container(block_ast.Document, []), parse_line)
  |> ast.invert_split()
}
