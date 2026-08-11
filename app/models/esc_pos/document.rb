# Builds an ESC/POS byte stream for a thermal receipt printer.
#
# The printer has no layout engine: it prints a stream of bytes top to bottom in
# a fixed-width monospace font, and control sequences switch alignment, weight
# and size as the stream goes by. So this is a append-only builder, and styles
# are blocks rather than flags to guarantee the stream is left in a known state:
#
#   EscPos::Document.new.build do |d|
#     d.center { d.double_size { d.text "VIANDANTE" } }
#     d.row "TOTAL", "$144.00"
#     d.cut
#   end
#
# Text is encoded to CP437 (the printer's default code page, selected explicitly
# in #reset) because the panel fonts are byte-indexed, not Unicode: "ñ" is one
# byte, 0xA4. Characters outside CP437 degrade to "?" rather than raising, since
# a product name with an unexpected glyph must not take the whole receipt down.
class EscPos::Document
  # Font A is 12 dots wide and the TM-T81 prints 512 dots, so 42 columns. Every
  # width calculation here (rows, rules, wrapping) is in those columns.
  COLUMNS = 42

  ESC = "\e"
  GS  = "\x1d"

  CODE_PAGE = "CP437"

  def initialize(columns: COLUMNS)
    @columns = columns
    @double_width = false
    @out = "".b
    reset
  end

  def build
    yield self
    self
  end

  # --- structure -----------------------------------------------------------

  def reset
    raw "#{ESC}@"          # initialise: clears leftover style from a killed job
    raw "#{ESC}t\x00"      # select CP437
    self
  end

  # Wraps at the current effective width, which halves inside a double-width
  # block: the printer has no idea a heading is too wide and simply breaks it
  # mid-word, and the preview cannot show that because it re-centres the string
  # it was given.
  def text(string = "")
    lines = @double_width ? wrap(string.to_s, effective_columns) : [string.to_s]
    lines.each { |line| write line }
    self
  end

  # Wraps to the column width, indenting continuation lines so a wrapped
  # product name reads as one item rather than two.
  #
  # Leading spaces are preserved and applied to every line: callers indent
  # ingredient and extra lines to nest them under their item, and losing that on
  # the first line alone would make the nesting look broken. The continuation
  # width accounts for both the lead and the indent, otherwise the lines this
  # method emits are themselves too wide and the printer re-breaks them flush
  # left, which is the exact nesting it exists to protect.
  def wrapped(string, indent: "  ")
    string = string.to_s
    lead = string[/\A */]
    body = string[lead.length..]

    lines = wrap(body, effective_columns - lead.length,
                       effective_columns - lead.length - indent.length)

    write "#{lead}#{lines.shift}"
    lines.each { |line| write "#{lead}#{indent}#{line}" }
    self
  end

  # Label left, value right, filled to the full width. The pair is truncated
  # rather than wrapped: a total that wraps is worse than one that is clipped.
  def row(left, right)
    left, right = left.to_s, right.to_s
    gap = effective_columns - left.length - right.length
    if gap < 1
      left = left[0, [effective_columns - right.length - 1, 1].max]
      gap = [effective_columns - left.length - right.length, 1].max
    end
    write "#{left}#{" " * gap}#{right}"
  end

  def rule(char = "-", width: effective_columns)
    write char * width
  end

  def feed(lines = 1)
    raw "\n" * lines
    self
  end

  # Feeds past the blade before cutting, otherwise the cut lands mid-content.
  def cut(feed_lines: 4)
    feed feed_lines
    raw "#{GS}VA\x00"
    self
  end

  # --- styles --------------------------------------------------------------

  def center
    raw "#{ESC}a\x01"
    yield
    raw "#{ESC}a\x00"
    self
  end

  def bold
    raw "#{ESC}E\x01"
    yield
    raw "#{ESC}E\x00"
    self
  end

  def double_height(&block)
    sized("\x01", &block)
  end

  def double_size(&block)
    sized("\x11", &block)
  end

  # CODE39 needs its own start/stop delimiters and accepts only a subset of
  # ASCII, so anything else is dropped rather than sent as an invalid symbol.
  def barcode(code, height: 80)
    payload = code.to_s.upcase.gsub(/[^0-9A-Z\-.$\/+% ]/, "")
    return self if payload.empty?

    raw "#{GS}h#{height.chr}"   # height in dots
    raw "#{GS}w\x02"            # module width
    raw "#{GS}H\x00"            # no human-readable text
    raw "#{GS}k\x04*#{payload}*\x00"
    self
  end

  def raw(bytes)
    @out << bytes.b
    self
  end

  def to_s
    @out
  end

  private

  def write(line)
    raw encode(line)
    raw "\n"
  end

  # Greedy word wrap. `rest` is the width available to continuation lines, which
  # is smaller than `first` whenever the caller indents them. A word longer than
  # the width is split hard rather than emitted whole: the printer would break it
  # anyway, at a column of its choosing and with no indent.
  def wrap(string, first, rest = first)
    remaining = string.to_s.strip
    return [""] if remaining.empty?

    lines = []
    until remaining.empty?
      width = [lines.empty? ? first : rest, 1].max

      if remaining.length <= width
        lines << remaining
        break
      end

      cut = remaining.rindex(" ", width)
      if cut.nil? || cut.zero?
        lines << remaining[0, width]
        remaining = remaining[width..].lstrip
      else
        lines << remaining[0, cut]
        remaining = remaining[(cut + 1)..].lstrip
      end
    end
    lines
  end

  # Double width halves how many characters fit on a line. Height does not.
  def effective_columns
    @double_width ? @columns / 2 : @columns
  end

  def sized(mode)
    previous = @double_width
    @double_width = (mode.ord >> 4).positive?
    raw "#{GS}!#{mode}"
    yield
    raw "#{GS}!\x00"
    @double_width = previous
    self
  end


  def encode(string)
    string.to_s.encode(CODE_PAGE, invalid: :replace, undef: :replace, replace: "?")
  end
end
