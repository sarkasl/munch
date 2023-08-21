import gleam/io
import gleam/string
import ast
import block

pub fn main() {
  // let assert Ok(line) = erlang.get_line("")
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
