// Typst template for the PDF version of cv.qmd.
// Rendered by the Typst engine bundled with Quarto: no extra install needed.
// Colours and fonts follow the website theme (styles.scss).

// ---- Theme -----------------------------------------------------------------
#let teal = rgb("#0F766E")      // primary colour on the website
#let ink = rgb(33, 37, 41)      // entry titles
#let body-ink = rgb(55, 58, 60) // body colour
#let muted = rgb(95, 99, 102)   // footer colour: dates, institutions
#let hairline = rgb(15, 118, 110, 45) // teal at low opacity

#let serif = ("Lora",)
#let sans = ("Source Sans 3",)

// ---- Layout ----------------------------------------------------------------
#let gutter = 25mm      // width of the date column
#let gap = 6mm          // space between date column and content

// One CV entry: date on the left, content on the right
// (compact: entries without bullets, e.g. courses and trainings)
#let entry(date, body, compact: false) = block(
  breakable: false,
  above: 0pt,
  below: if compact { 0.8em } else { 1.2em },
  grid(
    columns: (gutter, 1fr),
    column-gutter: gap,
    text(size: 9.5pt, fill: muted, date),
    body,
  ),
)

// Content without a date, aligned with the entry text column
#let plain(body) = block(
  above: 0pt,
  sticky: true, // keep sub-headings (e.g. "Tutor") with what follows
  below: 1.1em,
  pad(left: gutter + gap, body),
)

// Small group label inside a section (e.g. "Book Chapter", "Workshops")
#let group(body) = block(
  above: 1.6em,
  sticky: true,
  below: 0.9em,
  pad(left: gutter + gap, text(
    size: 9pt,
    weight: "semibold",
    tracking: 0.06em,
    fill: teal,
    upper(body),
  )),
)

// ---- Document --------------------------------------------------------------
#let cv(
  title: none,
  author: "",
  body,
) = {
  set document(title: author + " – Curriculum Vitae", author: author)

  set page(
    paper: "a4",
    margin: (x: 18mm, top: 16mm, bottom: 18mm),
    footer: context align(right, text(
      size: 8pt,
      fill: muted,
      [#author · CV · #counter(page).display("1 / 1", both: true)],
    )),
  )

  set text(font: sans, size: 10.5pt, lang: "en", fill: body-ink)
  set par(leading: 0.85em, spacing: 0.95em) // ~1.5 line height
  set list(
    indent: 0pt,
    body-indent: 0.55em,
    spacing: 0.75em,
    marker: text(fill: teal)[•],
  )
  show list: set block(above: 0.6em)

  show link: set text(fill: teal)
  set strong(delta: 200)
  show strong: set text(fill: ink)
  show emph: set text(fill: muted)
  // italics inside a bold title (species names) keep the title colour
  show strong: it => { show emph: set text(fill: ink); it }

  // Section headings: Lora, teal, with a hairline rule (like the website)
  show heading: it => block(
    above: 1.8em,
    below: 1.05em,
    sticky: true,
    width: 100%,
  )[
    #set text(font: serif, size: 14pt, weight: "semibold", fill: teal)
    #it.body
    #v(-0.45em)
    #line(length: 100%, stroke: 0.6pt + hairline)
  ]

  // Name block
  align(center, text(font: serif, size: 24pt, weight: "semibold", fill: teal, author))
  v(-0.2em)

  body
}
