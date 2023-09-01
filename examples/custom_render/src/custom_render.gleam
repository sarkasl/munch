import gleam/list
import gleam/string
import gleam/int
import gleam/io
import gleam/option
import nakai
import nakai/html
import nakai/html/attrs
import munch/md.{MarkdownNode}

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

pub fn render_nakai(node: MarkdownNode) -> html.Node(a) {
  let children = list.map(node.children, render_nakai)

  case node.value {
    md.Document -> html.Fragment(children)
    md.ThematicBreak -> html.hr([])
    md.Heading(level) ->
      case level {
        1 -> html.h1([], children)
        2 -> html.h2([], children)
        3 -> html.h3([], children)
        4 -> html.h4([], children)
        5 -> html.h5([], children)
        _ -> html.h6([], children)
      }
    md.CodeBlock(info, text) ->
      html.pre([], [html.code_text([attrs.class("language-" <> info)], text)])
    md.HtmlBlock(text) -> html.UnsafeText(text)
    md.Paragraph -> html.p([], children)
    md.BlockQuote -> html.blockquote([], children)
    md.Table -> html.table([], children)
    md.TableHeader -> html.thead([], children)
    md.TableBody -> html.tbody([], children)
    md.TableRow -> html.tr([], children)
    md.TableHeaderCell -> html.th([], children)
    md.TableDataCell -> html.td([], children)
    md.UnorderedList -> html.ul([], children)
    md.OrderedList(1) -> html.ol([], children)
    md.OrderedList(start) ->
      html.ol([attrs.Attr("start", int.to_string(start))], children)
    md.ListItem -> html.li([], children)
    md.TaskListItem(True) ->
      html.li(
        [],
        [
          html.input([
            attrs.type_("checkbox"),
            attrs.disabled(),
            attrs.checked(),
          ]),
          ..children
        ],
      )
    md.TaskListItem(False) ->
      html.li(
        [],
        [html.input([attrs.type_("checkbox"), attrs.disabled()]), ..children],
      )
    md.Text(text) -> html.Text(text)
    md.CodeSpan(text) -> html.code_text([], text)
    md.Emphasis -> html.em([], children)
    md.StrongEmphasis -> html.strong([], children)
    md.StrikeThrough -> html.del([], children)
    md.Link(href, option.None) -> html.a([attrs.href(href)], children)
    md.Link(href, option.Some(title)) ->
      html.a([attrs.href(href), attrs.title(title)], children)
    md.Image(src, alt, option.None) ->
      html.img([attrs.src(src), attrs.alt(alt)])
    md.Image(src, alt, option.Some(title)) ->
      html.img([attrs.src(src), attrs.alt(alt), attrs.title(title)])
    md.Softbreak -> html.Text("\n")
    md.Hardbreak -> html.br([])
  }
}
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
