# Renders an ESC/POS stream back into readable text, the way it would land on
# paper. For looking at a receipt during development without feeding a roll
# through the printer for every change.
#
# This interprets the control sequences rather than stripping them, so centring
# and double-width are reflected in the output: a centred double-size heading
# only occupies half the columns, and lining that up on screen is the whole point
# of a preview.
class EscPos::Preview
  ESC = "\e".b
  GS  = "\x1d".b

  def initialize(bytes, columns: EscPos::Document::COLUMNS)
    @bytes = bytes.b
    @columns = columns
  end

  def to_text
    @lines = []
    @buffer = "".b
    @align = :left
    @double_width = false
    @position = 0

    scan
    flush

    @lines.join("\n")
  end

  private

  def scan
    while @position < @bytes.length
      byte = @bytes[@position]

      case byte
      when ESC then escape
      when GS  then group_separator
      when "\n".b then @position += 1; flush(force: true)
      else
        @buffer << byte
        @position += 1
      end
    end
  end

  def escape
    case @bytes[@position + 1]
    when "@".b then advance 2                                    # initialise
    when "t".b then advance 3                                    # code page
    when "E".b then advance 3                                    # bold
    when "a".b then align @bytes[@position + 2]; advance 3
    else advance 2
    end
  end

  def group_separator
    case @bytes[@position + 1]
    when "!".b then size @bytes[@position + 2]; advance 3
    when "V".b then advance 4; marker "- - - - - -  corte  - - - - - -"
    when "h".b, "w".b, "H".b then advance 3                      # barcode setup
    when "k".b then barcode
    when "v".b then image
    else advance 2
    end
  end

  def barcode
    terminator = @bytes.index("\x00".b, @position + 3)
    payload = @bytes[(@position + 3)...terminator]
    @position = terminator + 1
    marker "[ codigo de barras: #{payload.delete("*")} ]"
  end

  # GS v 0 m xL xH yL yH, then xL+xH*256 bytes per row for yL+yH*256 rows. The
  # mode byte `m` sits at offset 3, so the width starts at 4 and the header is
  # 8 bytes long.
  def image
    width_bytes = @bytes[@position + 4].ord + (@bytes[@position + 5].ord << 8)
    rows = @bytes[@position + 6].ord + (@bytes[@position + 7].ord << 8)
    @position += 8 + (width_bytes * rows)
    marker "[ imagen #{width_bytes * 8}x#{rows} ]"
  end

  # Anything the printer draws rather than types. Pending text goes out first so
  # the marker cannot overtake the line it belongs after.
  def marker(text)
    flush
    line text
  end

  def align(byte)
    @align = byte == "\x01".b ? :center : :left
  end

  # The low nibble is the width multiplier; anything non-zero halves how many
  # characters fit on the line.
  def size(byte)
    @double_width = (byte.ord >> 4) > 0
  end

  def advance(bytes)
    @position += bytes
  end

  # A newline always ends a line, even an empty one, which is how blank spacing
  # survives into the preview. Everywhere else an empty buffer has nothing to
  # emit.
  def flush(force: false)
    return if @buffer.empty? && !force

    line @buffer.dup.force_encoding("CP437").encode("UTF-8")
    @buffer.clear
  end

  def line(text)
    @lines << (@align == :center ? text.center(effective_columns).rstrip : text)
  end

  def effective_columns
    @double_width ? @columns / 2 : @columns
  end
end
