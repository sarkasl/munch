import gleam/string
import munch/md

pub fn main() {
  let input =
    string.trim(
      "
# On the importance of headings

This paragraph is going for pretty long.
This should continue it  
i wonder what this does

this should not

> quote
> cont mayb
> > yaya
> this should be wierd
> # hg

> separate

### closing
### thoughts
  ",
    )

  md.parse(input)
}
// https://spec.commonmark.org/dingus/?text=%23%20On%20the%20importance%20of%20headings%0A%0AThis%20paragraph%20is%20going%20for%20pretty%20long.%0AThis%20should%20continue%20it%20%20%0Ai%20wonder%20what%20this%20does%0A%0Athis%20should%20not%0A%0A%3E%20quote%0A%3E%20cont%20mayb%0A%3E%20%3E%20yaya%0A%3E%20this%20should%20be%20wierd%0A%3E%20%23%20hg%0A%0A%3E%20separate%0A%0A%23%23%23%20closing%0A%23%23%23%20thoughts