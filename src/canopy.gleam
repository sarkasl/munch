import gleam/io
import gleam/string
import canopy/ast
import canopy/block

pub fn to_html(_input: String) -> String {
  "todo"
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
  |> block.parse()
  |> ast.repr_split()
  |> io.println()
}
