import gleam/list
import gleam/string
import gleam/int
import gleam/io
import nakai
import nakai/html
import gala.{MarkdownElement, MarkdownNode}
import gala/tree.{Node}

// pub fn render(node: MarkdownNode) -> String {
//   let children =
//     node.children
//     |> list.map(render)
//     |> string.concat()

//   case node.value {
//     canopy.Document -> children
//     canopy.BlockQuote -> "<blockquote>" <> children <> "</blockquote>"
//     canopy.Paragraph -> "<p>" <> text <> "</p>"
//     Heading(level, text) -> {
//       let level_str = int.to_string(level)
//       "<h" <> level_str <> ">" <> text <> "</h" <> level_str <> ">"
//     }
//     NumberedList -> "<ol>" <> children <> "</ol>"
//     ListItem -> "<li>" <> children <> "</li>"
//   }
// }

// pub fn render_nakai(node: MarkdownNode) -> html.Node(a) {
//   let children = list.map(node.children, render_nakai)

//   case node.value {
//     Document -> html.div([], children)
//     Quote -> html.blockquote([], children)
//     Paragraph(text) -> html.p_text([], text)
//     Heading(level, text) ->
//       case level {
//         1 -> html.h1_text([], text)
//         2 -> html.h2_text([], text)
//         3 -> html.h3_text([], text)
//         4 -> html.h4_text([], text)
//         5 -> html.h5_text([], text)
//         _ -> html.h6_text([], text)
//       }
//     NumberedList -> html.ol([], children)
//     ListItem -> html.li([], children)
//   }
// }

// fn add_heading(acc: MarkdownNode, node: MarkdownElement) -> MarkdownNode {
//   case node {
//     Heading(level, _) ->
//       case acc {
//         Node(value, [Node(Heading(child_level, _), _) as child, ..rest]) if level <= child_level -> {
//           Node(value, [Node(node, []), child, ..rest])
//         }
//         Node(value, [child, ..rest]) -> {
//           Node(value, [add_heading(child, node), ..rest])
//         }
//         Node(value, []) -> {
//           Node(value, [Node(node, [])])
//         }
//       }
//     _ -> acc
//   }
// }

// pub fn main() {
//   let markdown_ast =
//     Node(
//       Document,
//       [
//         Node(Heading(1, "This is a heading"), []),
//         Node(Paragraph("Paragraph text"), []),
//         Node(Heading(3, "Smaller heading"), []),
//         Node(
//           Quote,
//           [
//             Node(Paragraph("Paragraph in quote"), []),
//             Node(Heading(3, "Heading in quote"), []),
//             Node(Quote, [Node(Heading(1, "Big heading in quote"), [])]),
//           ],
//         ),
//         Node(
//           NumberedList,
//           [
//             Node(ListItem, [Node(Heading(4, "Last heading"), [])]),
//             Node(ListItem, [Node(Paragraph("Paragraph in list"), [])]),
//           ],
//         ),
//       ],
//     )

//   io.println("Original tree:")
//   markdown_ast
//   |> tree.pretty_print()
//   io.println("")

//   io.println("All headings:")
//   let heading_tree =
//     markdown_ast
//     |> tree.fold(Node(Document, []), add_heading)
//     |> tree.reverse()
//   tree.pretty_print(heading_tree)
//   io.println("")

//   markdown_ast
//   |> render()
//   |> io.println()
//   io.println("")

//   markdown_ast
//   |> render_nakai()
//   |> nakai.to_string()
//   |> io.println()
//   io.println("")
// }
