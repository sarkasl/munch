import gleam/io
import gleam/string
import canopy/ast
import canopy/internal/block

//.{BlockNode}

// fn parse_inline(block_tree: BlockNode)

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
  |> block.parse()
  |> ast.repr_split()
  |> io.println()
}

pub fn to_html(_input: String) -> String {
  "todo"
}

pub fn parse(input: String) -> String {
  input
  |> block.parse()
  |> ast.repr_split()
}
