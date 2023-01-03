# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::CoverageParser::BlockComposer do
  subject(:composer) { described_class }

  let(:payload) { fixture_file("coverage_b64.txt") }

  it "handles specific kinds" do
    lines = %i[a b c d]
    res = composer.group(lines)
    expect(res).to eq [
      { kind: :a, start: 1, end: 1 },
      { kind: :b, start: 2, end: 2 },
      { kind: :c, start: 3, end: 3 },
      { kind: :d, start: 4, end: 4 }
    ]
  end

  it "handles contiguous blocks" do
    lines = Cocov::CoverageParser.parse(payload)
    expect(composer.group(lines)).to eq [
      { kind: :neutral, start: 1, end: 2 },
      { kind: :covered, start: 3, end: 6 },
      { kind: :neutral, start: 7, end: 13 },
      { kind: :covered, start: 14, end: 16 },
      { kind: :neutral, start: 17, end: 17 },
      { kind: :covered, start: 18, end: 18 },
      { kind: :neutral, start: 19, end: 25 },
      { kind: :covered, start: 26, end: 27 },
      { kind: :neutral, start: 28, end: 28 },
      { kind: :covered, start: 29, end: 31 },
      { kind: :neutral, start: 32, end: 32 },
      { kind: :covered, start: 33, end: 34 },
      { kind: :neutral, start: 35, end: 35 },
      { kind: :covered, start: 36, end: 36 },
      { kind: :neutral, start: 37, end: 37 },
      { kind: :covered, start: 38, end: 39 },
      { kind: :neutral, start: 40, end: 40 },
      { kind: :covered, start: 41, end: 42 },
      { kind: :neutral, start: 43, end: 49 },
      { kind: :covered, start: 50, end: 51 },
      { kind: :neutral, start: 52, end: 55 },
      { kind: :covered, start: 56, end: 56 },
      { kind: :neutral, start: 57, end: 57 },
      { kind: :covered, start: 58, end: 60 },
      { kind: :neutral, start: 61, end: 65 },
      { kind: :covered, start: 66, end: 66 },
      { kind: :missed, start: 67, end: 67 },
      { kind: :neutral, start: 68, end: 73 },
      { kind: :covered, start: 74, end: 75 },
      { kind: :neutral, start: 76, end: 78 },
      { kind: :covered, start: 79, end: 79 },
      { kind: :ignored, start: 80, end: 90 },
      { kind: :neutral, start: 91, end: 96 },
      { kind: :covered, start: 97, end: 97 },
      { kind: :missed, start: 98, end: 98 },
      { kind: :neutral, start: 99, end: 107 },
      { kind: :missed, start: 108, end: 111 },
      { kind: :neutral, start: 112, end: 117 },
      { kind: :covered, start: 118, end: 123 },
      { kind: :neutral, start: 124, end: 125 },
      { kind: :covered, start: 126, end: 126 },
      { kind: :neutral, start: 127, end: 130 }
    ]
  end
end
