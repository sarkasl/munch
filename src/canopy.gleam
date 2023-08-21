import gleam/io
import gleam/string
import canopy/ast
import canopy/block

pub fn to_html(input: String) -> String {
  "todo"
}

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
