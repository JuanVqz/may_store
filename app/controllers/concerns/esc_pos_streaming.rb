# Sends an ESC/POS byte stream to the browser, which forwards it to the thermal
# printer over WebUSB.
#
# The bytes are already CP437-encoded and carry their own control sequences, so
# the response must not be touched by any character-set conversion on the way
# out; `send_data` with a binary type is what guarantees that.
#
# Requesting `.txt` renders the same stream as readable text instead, which is
# how development looks at a receipt without feeding paper through the printer.
module EscPosStreaming
  extend ActiveSupport::Concern

  MIME_TYPE = "application/vnd.escpos"

  private

  def send_escpos(bytes, filename:)
    if params[:format] == "txt"
      render plain: EscPos::Preview.new(bytes).to_text
    else
      send_data bytes, type: MIME_TYPE, disposition: "inline", filename: "#{filename}.bin"
    end
  end
end
