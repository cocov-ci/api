# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::SchemaValidator::AltValidator do
  subject(:validator) { described_class.new([:foo, "bar"]) }

  it "validates :foo" do
    expect { validator.validate(:foo, []) }.not_to raise_error
  end

  it "validates \"bar\"" do
    expect { validator.validate("bar", []) }.not_to raise_error
  end

  it "rejects :baz" do
    expect { validator.validate(:baz, []) }.to raise_error(Cocov::SchemaValidator::ValidationError)
  end

  it "identifies itself" do
    expect(validator.inspect).to eq "alt(:foo, \"bar\")"
  end
end
