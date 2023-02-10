# frozen_string_literal: true

module Cocov
  class Highlighter
    def initialize(commit, path:, range: nil)
      @commit = commit
      @path = path
      @range = range
    end

    def insert_warning(line, message)
      @warning = { line:, message: }
      self
    end

    def generate_html(lang, source)
      event_name = "cocov.format.file"
      opts = { source_length: source.length, language: lang }
      ActiveSupport::Notifications.instrument(event_name, opts) do
        lexer = Rouge::Lexer.find(lang) || Rouge::Lexer.find("text")
        html_formatter = Rouge::Formatters::HTML.new
        formatter = Rouge::Formatters::HTMLLineTable.new(html_formatter, {
          start_line: (@range&.first || 1)
        })
        formatter.format(lexer.lex(source))
      end
    end

    def parse_html(html)
      data = []
      fragment = Nokogiri::HTML5.fragment(html)
      fragment.css("table > tbody > .lineno").each do |line|
        line_number = line.css("td.rouge-gutter > pre").inner_text.to_i
        source_line = line.css(".rouge-code").inner_html
        data << { type: :line, line: line_number, source: source_line }

        next if !@warning || @warning[:line] != line_number

        data << {
          type: :warn,
          text: @warning[:message],
          padding: padding_for(line.css("pre")[1].children.first.inner_text)
        }
      end

      data
    end

    SPACE_MATCHER = /^(\s*)/
    def padding_for(text)
      SPACE_MATCHER.match(text)&.captures&.first || ""
    end

    def contents = @contents ||= GitService.file_for_commit(@commit, path: @path, range: @range)

    def format
      cache_key = Digest::SHA1.hexdigest ["formatted", @commit.repository.name, @commit.sha, @path,
                                          @range&.to_a].compact.join

      Cocov::Redis.cached_formatted_file(cache_key) do
        lang, source = contents
        html = generate_html(lang, source)
        parse_html(html)
      end
    end
  end
end
