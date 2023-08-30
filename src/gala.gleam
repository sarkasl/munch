import gleam/string
import gala/md

pub fn main() {
  let input =
    string.trim(
      "
  ## 
  #
  ### ###
  ",
    )

  md.parse(input)
}
