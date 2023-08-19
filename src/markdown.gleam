import gleam/io
import gleam/erlang

pub fn main() {
  let assert Ok(line) = erlang.get_line("")
  io.println(line)
}
