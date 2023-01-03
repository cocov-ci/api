# frozen_string_literal: true

module Cocov
  class CoverageParser
    class << self
      def parse(data)
        new.parse(data).lines
      end
    end

    def initialize
      @lines = []
      @tmp = []
    end

    def parse(data)
      # Decode as base64 unless string contains control characters
      # (except \r, \n, \t)
      data = Base64.decode64(data) unless /[\x00-\x09\x0C\x0E-\x1F]/.match?(data)
      data.each_byte { feed(_1) }
      self
    end

    def reset
      @lines.clear
      @tmp.clear
    end

    def lines
      flush_ascii_data
      @lines
    end

    SEPARATOR = 0x1E
    NEUTRAL   = 0x00
    IGNORE    = 0x1B
    MISSED    = 0x15

    def flush_ascii_data
      return if @tmp.empty?

      @lines << @tmp.pack("C*").to_i
      @tmp.clear
    end

    def feed(b)
      case b
      when NEUTRAL
        flush_ascii_data
        @lines << :neutral
      when SEPARATOR
        flush_ascii_data
      when IGNORE
        flush_ascii_data
        @lines << :ignored
      when MISSED
        flush_ascii_data
        @lines << 0
      when 0x30..0x39
        @tmp << b
      else
        raise ArgumentError, "Error decoding coverage data: Unexpected control byte 0x#{b.to_s(16)}"
      end
    end
  end
end
