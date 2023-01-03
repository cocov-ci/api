# frozen_string_literal: true

json.call(cov, :status)

if cov.ready?
  json.call(cov, :percent_covered, :lines_total, :lines_covered)
  json.least_covered least_covered do |c|
    json.call(c, :id, :file, :percent_covered)
  end
end
