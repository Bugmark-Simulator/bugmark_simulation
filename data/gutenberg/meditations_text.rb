DOC_FILE = File.expand_path("./Meditations.txt", __dir__)

class MeditationsText
  attr_reader :fname, :paras

  def initialize(fname = DOC_FILE)
    @fname = fname
    @paras = File.readlines(fname, "\r\n\r\n").select {|el| el.length > 100}
  end

  def plain_para
    clean(@paras.sample)
  end

  def marked_para
    markup(@paras.sample)
  end

  private

  def clean(text)
    wrap(text.split(" ").join(" "))
  end

  def markup(text)
    words = text.split(" ")
    offsets = (1..words.length-1).to_a.shuffle[1..3]
    offsets.each {|idx| words[idx] = "<b>#{words[idx]}</b>"}
    wrap(words.join(" "))
  end

  def wrap(text, line_width: 60, break_sequence: "\n")
    text.split("\n").collect! do |line|
      line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1#{break_sequence}").strip : line
    end * break_sequence
  end
end

MT = MeditationsText
