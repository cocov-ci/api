# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::SchemaValidator::NilValidator do
  subject(:validator) { described_class.new }

  it "validates nil" do
    expect { validator.validate(nil, []) }.not_to raise_error
  end

  it "rejects non-nil" do
    expect { validator.validate(:lol, []) }.to raise_error(Cocov::SchemaValidator::ValidationError)
  end

  it "identifies itself" do
    expect(validator.inspect).to eq "nil"
  end
end
