# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::SchemaValidator::SymbolValidator do
  subject(:validator) { described_class.new }

  it "validates symbol" do
    expect { validator.validate(:sym, []) }.not_to raise_error
  end

  it "rejects non-symbol" do
    expect { validator.validate(1, []) }.to raise_error(Cocov::SchemaValidator::ValidationError)
  end

  it "identifies itself" do
    expect(validator.inspect).to eq "symbol"
  end
end
