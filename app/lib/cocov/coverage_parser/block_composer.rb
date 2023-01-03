# frozen_string_literal: true

module Cocov
  class CoverageParser
    class BlockComposer
      def self.group(lines)
        lines = lines.map do |n|
          if n.is_a? Symbol
            n
          elsif n.zero?
            :missed
          else
            :covered
          end
        end
        new(lines).process
      end

      def initialize(lines)
        @lines = lines
        @last = lines.shift
        @last_number = 1

        @line_number = 1
        @result = []
      end

      def push_group(current)
        @result << { kind: @last, start: @last_number, end: @line_number - 1 }
        @last = current
        @last_number = @line_number
      end

      def process
        @lines.each do |line|
          @line_number += 1

          push_group(line) if line != @last
        end

        @line_number += 1
        push_group(:end)

        @result
      end
    end
  end
end
