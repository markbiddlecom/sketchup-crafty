# frozen_string_literal: true

module Crafty
  module Util
    class FuzzyNumeric
      # The default threshold for fuzzy comparisons
      DEFAULT_THRESHOLD = 1e-7

      # @return [Float] the value wrapped by this numeric
      attr_reader :value

      # @return [Float] the comparison threshold
      attr_reader :threshold

      # @param value [#to_f] the value to wrap
      # @param threshold [Numeric] the threshold for comparisons with this value
      def initialize(value, threshold = DEFAULT_THRESHOLD)
        @value = value.to_f
        @threshold = threshold.to_f
      end

      # @return [Float] the value wrapped by this numeric
      def to_f
        @value
      end

      # @return [String] a string representation of this numeric
      def to_s
        "#{@value}@#{threshold}"
      end

      # @param other [#to_f] an instance convertible to a float
      # @return [Boolean] `true` if these values are equivalent and `false` otherwise
      def ==(other)
        return false if other.nil? || !(other.respond_to? :to_f)

        (@value - other.to_f).abs <= @threshold
      end
    end # class FuzzyNumeric
  end # module Util
end # module Crafty
