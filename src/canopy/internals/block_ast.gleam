import gleam/string_builder.{StringBuilder}
import canopy/ast

pub type BlockContainer {
  Document
  BlockQuote
}

// BulletList(bullet: String, justify: Int)
// OrderedList(start: Int, delimeter: String, justify: Int)
// ListItem

pub type BlockLeaf {
  Paragraph(text: StringBuilder)
  Heading(level: Int, text: String)
}

// IndentCode(text: StringBuilder)
// FencedCode(info: String, text: StringBuilder)
// ThematicBreak

pub type BlockNode =
  ast.SplitNode(BlockContainer, BlockLeaf)
