# frozen_string_literal: true

module TimeNormalizer
  extend ActiveSupport::Concern

  class_methods do
    def coerce_time_param(val)
      val = Time.zone.parse(val) unless val.is_a? Time
      val.beginning_of_day
    end

    def normalize_time_array(range, data, last_known)
      # In case data is empty, there's not much we can do. Just synthesise it
      # from the provided range
      return range.map { |d| { date: d, value: last_known } } if data.length.zero?

      [].tap do |arr|
        range.each.with_index do |ex, idx|
          if (item = data.find { _1[:date] == ex })
            arr << item
            next
          end

          if idx.zero?
            # If the first index does not exist, synthesise it based on the
            # last_known value provided
            arr << { date: ex.to_date, value: last_known }
            next
          end

          # At this point, the item does not exist and we are not on the first
          # index. Just copy the last item's value and be done with it.
          arr << { date: ex.to_date, value: arr.last[:value] }
        end
      end
    end

    def date_array(start, finish)
      start = start.to_date
      finish = finish.to_date
      (start..finish).to_a.last([finish - start, 1].max)
    end
  end
end
