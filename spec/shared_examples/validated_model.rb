# frozen_string_literal: true

RSpec.shared_examples "a validated model" do |fields|
  fields.each do |name|
    it "is not valid without #{name}" do
      subject.send("#{name}=", nil)
      expect(subject).not_to be_valid
    end
  end

  it "is valid with required fields" do
    expect(subject).to be_valid
  end

  it "stores a record" do
    expect { subject.save! }.not_to raise_error
  end
end
