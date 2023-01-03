# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::SchemaValidator::OptValidator do
  subject(:validator) { described_class.new(:foo) }

  it "validates :foo" do
    expect { validator.validate(:foo, []) }.not_to raise_error
  end

  it "validates nil" do
    expect { validator.validate(nil, []) }.not_to raise_error
  end

  it "rejects :baz" do
    expect { validator.validate(:baz, []) }.to raise_error(Cocov::SchemaValidator::ValidationError)
  end

  it "identifies itself" do
    expect(validator.inspect).to eq ":foo?"
  end
end
