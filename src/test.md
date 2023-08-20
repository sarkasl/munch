> Lorem ipsum dolor
sit amet
> > Qui quodsi iracundia
> > aliquando id
> > # hey
> hii


start

document open, no children -> create child
  create block quote
  create block paragraph

document open, child ->
  close child? yes
  quote closed, leaf child ->
    append? yes
    abstain, dirty ->
  abstain, dirty ->

document open, child ->
  close child? no
  strip
  quote open, leaf child ->
    append? no
    closing, dirty ->
    create block quote
    create block paragraph
  abstain, dirty ->

document open, child ->
  close child? no
  strip
  quote open, child ->
    close child? no
    strip
    quote open, leaf child ->
      append? yes
      abstain, dirty ->
    abstain, dirty ->
  abstain, dirty ->
    
document open, child ->
  close child? no
  strip
  quote open, child ->
    close child? no
    strip
    quote open, leaf child ->
      append? no
      closing, clean ->
      create block heading
    abstain, dirty ->
  abstain, dirty ->

document open, child ->
  close child? no
  strip
  quote open, child ->
    close child? yes
    quote closed, leaf child ->
      append? no
      closed, clean ->
    closing, clean ->


document
  block_quote
    paragraph
      "Lorem ipsum dolor\nsit amet"
    block_quote
      paragraph
        "Qui quodsi iracundia\naliquando id"
      heading 1
        "hey"


