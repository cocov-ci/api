# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::Trigram do
  subject(:helper) { described_class }

  it "extracts trigrams from a given input" do
    expected = [
      "  a", "  i", "  t", " a ", " is", " te", " th", "est", "his", "is ", "st ", "tes", "thi"
    ]

    actual = helper.trigrams_of("this is a test")
    expect(actual).to eq expected
  end

  {
    ["word", "two words"] => 0.36363637,
    %w[word words] => 0.5714286,
    ["this is a test", "but this is not"] => 0.33333334
  }.each do |words, sim|
    a, b = words
    it "determines similiarity of '#{a}' and '#{b}'" do
      calculated = helper.similarity_of(a, b)
      expect(calculated).to be_within(0.0001).of(sim)
    end
  end
end
