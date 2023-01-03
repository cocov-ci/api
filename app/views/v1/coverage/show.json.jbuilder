# frozen_string_literal: true

json.file do
  path = Pathname.new(file.file)
  json.base_path "#{path.dirname}/"
  json.name path.basename.to_s
  json.source source
end

json.coverage do
  json.call(file, :lines_covered, :lines_total, :percent_covered)
  json.blocks blocks
end
