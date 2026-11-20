#show: cv.with(
$if(title)$
  title: [$title$],
$endif$
  author: "$for(by-author)$$it.name.literal$$sep$, $endfor$",
)
