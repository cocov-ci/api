# frozen_string_literal: true

json.status commit.coverage_status
if commit.coverage_processed? && coverage&.ready?
  json.files files do |file|
    json.call(file, :id, :file, :percent_covered)
  end
end
