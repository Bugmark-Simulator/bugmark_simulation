require 'csv'

CSV_FILE = File.expand_path("./Trivia1.csv", __dir__)

class ScramData
  class << self

    Scramble = Struct.new(:qstring, :astring) do
      def quiz
        "Unscramble this word: #{qstring}"
      end

      def quiz_word
        qstring.gsub(" ", "")
      end

      def quiz_level(level, prefix = "")
        "#{quiz_word}_#{prefix}#{level}"
      end

      def quiz_fn(level)
        "#{quiz_level(level)}.md"
      end

      def answer
        astring
      end

      def answer_line
        "#{qstring} |> #{astring}"
      end

      def hint(level)
        return "" if level == 0
        answer[0..level-1]
      end
    end

    def scrambles(max_lines = 10)
      data = []
      count = 0
      CSV.foreach(CSV_FILE) do |row|
        if row[1].start_with?("UnScramble")
          data.append(row_2_struct(row))
          count += 1
        end
        break if count >= max_lines
      end
      data
    end

    private

    def row_2_struct(row)
      qstr = row[1].gsub("UnScramble this Word:", "").strip
      astr = row[2]
      Scramble.new(qstr, astr)
    end
  end
end

SD = ScramData
