# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::Crypto do
  subject(:helper) { described_class }

  it "handles encrypted data" do
    stub_crypto_key!
    encrypted = helper.encrypt("Hello World")
    expect(helper.decrypt(encrypted)).to eq "Hello World"
  end

  it "ensures a crypto key is available" do
    expect { helper.encrypt("test") }.to raise_error(Cocov::Crypto::NoCryptographicKey)
  end
end
