# frozen_string_literal: true

module Crafty
  module Util
    # Represents a revolving sequence of options
    class Cycle
      # @param modes [Array<String, Symbol>] the modes the cycle will iterate through
      def initialize(*modes)
        @modes = modes
        # @type [Integer]
        @cur_mode = 0
      end

      # @return [String, Symbol] the current mode of this cycle.
      def cur_mode
        @modes[self.to_i]
      end

      # @param mode [String, Symbol] the mode to set this cycle to
      # @return [nil, String, Symbol] the provided `mode`, if it is an element of this cycle, or `nil` otherwise
      def cur_mode=(mode)
        @cur_mode = @modes.index(mode) if @modes.include? mode
        self.cur_mode
      end

      # @return [Integer] the integer value of this cycle's sequence
      def to_i
        @cur_mode % @modes.length
      end

      # Advances this cycle by the given amount
      # @param amount [#to_i] the number of changes to apply to the cycle
      # @return [Cycle] this cycle instance, for method chaining or comparison
      def advance!(amount = 1)
        @cur_mode += amount.to_i
        self
      end

      # Returns a new cycle equivalent to this cycle advanced by the given amount
      # @param other [#to_i] a value that is convertible to an integer
      # @return [Cycle] the new, incremented cycle
      def +(other)
        Cycle.new(@modes).with_index @cur_mode + other.to_i
      end

      # @param other [#to_i, Symbol, String, Cycle] the value to compare
      # @return [Boolean] `true` if both values currently represent cycles with the same current mode, and `false`
      #   otherwise.
      def ==(other)
        if other.is_a?(String) || other.is_a?(Symbol)
          self.cur_mode == other
        elsif other.is_a? Cycle
          self.cur_mode == other.cur_mode
        elsif other.respond_to? :to_i
          (@cur_mode % @modes.length) == (other.to_i % @modes.length)
        else
          false
        end
      end

      def to_s
        "Cycle(#{@modes.map.with_index { |m, i| i == self.to_i ? "[#{m}]" : m.to_s }.join(' ')})"
      end

      private

      # @param index [#to_i] the mode to set this to
      # @return [Cycle] this Cycle instance
      def with_index(index)
        @cur_mode = index.to_i
        self
      end
    end # class Cycle
  end # module Util
end # module Crafty
