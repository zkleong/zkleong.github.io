-- Adapts cv.qmd (written for HTML) to the Typst/PDF layout:
--   * an entry = paragraph with a [date]{.cvdate} span (+ its bullets and
--     "Supervisors:" line); the date moves to a left-hand column
--   * citation-style paragraphs ("... (2025). ...") use the year as the date
--   * a paragraph that is only **bold text** becomes a small group label
--   * everything else is indented to line up with the entry text
-- Only active for typst; the HTML and docx renders are untouched.

local site = "https://zkleong.com/"

if not quarto.doc.is_format("typst") then
  return {}
end

local months = {
  January = "Jan", February = "Feb", March = "Mar", April = "Apr",
  June = "Jun", July = "Jul", August = "Aug", September = "Sep",
  October = "Oct", November = "Nov", December = "Dec",
}

-- Escape characters that are special in Typst markup
local function typst_escape(s)
  return (s:gsub("([#%*_%[%]%$@<>`\\])", "\\%1"))
end

-- "August 2023 --- Present" -> "Aug 2023 –\ Present" (Typst markup)
local function format_date(s)
  -- (Lua patterns are byte-based, so multibyte dashes are matched literally)
  s = s:gsub("%s*—%s*", " – "):gsub("%s*–%s*", " – ")
  s = s:gsub("%s+%-%s+", " – "):gsub("(%d)%-(%d)", "%1–%2")
  for full, short in pairs(months) do
    s = s:gsub(full, short)
  end
  s = s:gsub("^S(%d)Y(%d%d%d%d)$", "Sem %1, %2")
  s = typst_escape(s)
  -- month ranges go on two lines in the narrow date column
  if s:match("%a") and s:match(" – ") then
    s = s:gsub(" – ", " –\\ ", 1)
  end
  return s
end

local function wrap(open, blocks)
  local out = { pandoc.RawBlock("typst", open) }
  for _, b in ipairs(blocks) do table.insert(out, b) end
  table.insert(out, pandoc.RawBlock("typst", "]"))
  return out
end

-- Remove the .cvdate span from a paragraph; return its text (or nil)
local function take_date(para)
  local date
  local kept = pandoc.List()
  for _, x in ipairs(para.content) do
    if x.t == "Span" and x.classes:includes("cvdate") then
      date = pandoc.utils.stringify(x.content)
    else
      kept:insert(x)
    end
  end
  if not date then return nil end
  while #kept > 0 and (kept[#kept].t == "Space" or kept[#kept].t == "SoftBreak"
      or kept[#kept].t == "LineBreak") do
    kept:remove()
  end
  para.content = kept
  return date
end

-- "(2025)." near the start of a citation-style paragraph
local function citation_year(para)
  for i, x in ipairs(para.content) do
    if i > 40 then break end
    if x.t == "Str" then
      local y = x.text:match("^%((%d%d%d%d)%)%.?$")
      if y then return y end
    end
  end
end

-- Formatted date for an entry paragraph, or nil if it isn't one
-- Cached per block, because take_date() removes the span on the first call
local date_cache = {}
local function entry_date(b)
  if b.t ~= "Para" then return nil end
  if date_cache[b] == nil then
    local d = take_date(b)
    date_cache[b] = (d and format_date(d)) or citation_year(b) or false
  end
  return date_cache[b] or nil
end

local function is_group_label(b)
  return b.t == "Para" and #b.content == 1 and b.content[1].t == "Strong"
end

local function is_supervisors(b)
  return b.t == "Para" and b.content[1] and b.content[1].t == "Str"
    and b.content[1].text == "Supervisors:"
end

-- Bullets that are just a link ("Certificate", "Slides") -> one inline row
local function fold_link_items(list)
  local items, links = pandoc.List(), pandoc.List()
  for _, item in ipairs(list.content) do
    local blk = item[1]
    if #item == 1 and (blk.t == "Plain" or blk.t == "Para")
        and #blk.content == 1 and blk.content[1].t == "Link" then
      links:insert(blk.content[1])
    else
      items:insert(item)
    end
  end
  local row
  if #links > 0 then
    local inl = pandoc.List()
    for i, l in ipairs(links) do
      if i > 1 then inl:insert(pandoc.Str(" · ")) end
      inl:insert(l)
    end
    row = pandoc.Para(inl)
  end
  return (#items > 0) and pandoc.BulletList(items) or nil, row
end

-- Flatten wrapper divs (e.g. .print-only around References)
local function flatten(blocks)
  local out = pandoc.List()
  for _, b in ipairs(blocks) do
    if b.t == "Div" and not b.classes:includes("contact-block") then
      out:extend(flatten(b.content))
    else
      out:insert(b)
    end
  end
  return out
end

local function layout(doc)
  local blocks = flatten(doc.blocks)
  local out = pandoc.List()
  local i = 1
  while i <= #blocks do
    local b = blocks[i]
    if b.t == "Header" then
      out:insert(b)
      i = i + 1
    elseif b.t == "Div" then -- contact block
      out:extend(wrap("#align(center)[", b.content))
      i = i + 1
    elseif is_group_label(b) then
      out:extend(wrap("#group[", { pandoc.Plain(b.content[1].content) }))
      i = i + 1
    elseif entry_date(b) then
      local date = entry_date(b)
      local body = pandoc.List({ b })
      local links
      i = i + 1
      -- absorb the entry's bullet list and supervisors line
      while blocks[i] and (blocks[i].t == "BulletList" or is_supervisors(blocks[i])) do
        local nb = blocks[i]
        if nb.t == "BulletList" then
          local list, row = fold_link_items(nb)
          if list then body:insert(list) end
          links = row
        else
          body:insert(nb)
        end
        i = i + 1
      end
      if links then body:insert(links) end
      -- one-line entries (course codes, short workshops) sit closer together
      local one_line = #body == 1 and not body[1].content:find_if(
        function(x) return x.t == "LineBreak" end)
      local compact = one_line and "compact: true, " or ""
      out:extend(wrap("#entry(" .. compact .. "[" .. date .. "])[", body))
    else
      out:extend(wrap("#plain[", { b }))
      i = i + 1
    end
  end
  doc.blocks = out
  return doc
end

return {
  {
    -- <br> is raw HTML, which Typst would drop: turn it into a line break
    RawInline = function(el)
      if el.format == "html" and el.text:match("^<br%s*/?>$") then
        return pandoc.LineBreak()
      end
    end,

    -- ***Institution*** (bold italic) -> plain italic, like other institutions
    Strong = function(el)
      if #el.content == 1 and el.content[1].t == "Emph" then
        return el.content[1]
      end
    end,
    Emph = function(el)
      if #el.content == 1 and el.content[1].t == "Strong" then
        return pandoc.Emph(el.content[1].content)
      end
    end,

    -- Relative links (certificates etc.) point at the live site from the PDF
    Link = function(el)
      if not el.target:match("^%a[%w+.-]*:") and not el.target:match("^#") then
        el.target = site .. el.target:gsub("^%./", "")
        return el
      end
    end,
  },
  { Pandoc = layout },
}
