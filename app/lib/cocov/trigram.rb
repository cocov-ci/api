# frozen_string_literal: true

module Cocov
  class Trigram
    class << self
      def trigrams_of(word)
        word = I18n.transliterate(word.to_s).downcase

        slices = word.split(/[\W_]+/).map do |w|
          next if w.empty?

          "  #{w} ".chars.each_cons(3).map(&:join)
        end

        Set.new(slices.flatten.compact).sort
      end

      def similarity_of(term_a, term_b)
        trigram_similarity(trigrams_of(term_a), trigrams_of(term_b))
      end

      def trigram_similarity(tgrm_a, tgrm_b)
        return 0 if tgrm_a.empty? && tgrm_b.empty?

        dups = tgrm_a & tgrm_b
        count = tgrm_a | tgrm_b

        dups.length.to_f / count.length
      end
    end
  end
end
