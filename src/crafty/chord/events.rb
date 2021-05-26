# frozen_string_literal: true

module Crafty
  module Chords
    class EnactEvent
      # @return [nil, Crafty::ToolStateMachine::Mode] this can optionally be set to a non-`nil` value by
      #   the event handler to indicate that the
      attr_reader :new_state
    end # class EnactEvent

    class ClickEnactEvent < EnactEvent
      # @param x [Numeric] the x-coordinate where the mouse was clicked
      # @param y [Numeric] the y-coordinate where the mouse was clicked
      def initialize(x, y)
        @x = x
        @y = y
      end

      # @return [Numeric] the x-coordinate where the mouse was clicked
      attr_reader :x

      # @return [Numeric] the y-coordinate where the mouse was clicked
      attr_reader :y
    end # class ClickEnactEvent

    class DragEnactEvent < EnactEvent
      # @param x_start [Numeric] the x-coordinate where the user started dragging
      # @param y_start [Numeric] the y-coordinate where the user started dragging
      # @param x_end [Numeric] the x-coordinate where the user ended dragging
      # @param y_end [Numeric] the y-coordinate where the user ended dragging
      def initialize(x_start, y_start, x_end, y_end)
        @bounds = Util.bounds_from_pts x_start, y_start, x_end, y_end
        @direction = x_end >= x_start ? :left_to_right : :right_to_left
      end

      # @return [Geom::Bounds2d] the bounds of the rectangle dragged by the user
      attr_reader :bounds

      # @return [Symbol] `:left_to_right` if the user started drawing the rectangle on the
      #   left side and `:right_to_left` otherwise.
      attr_reader :direction
    end # DragEnactEvent
  end # module Chords
end # module Crafty
