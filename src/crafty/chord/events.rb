# frozen_string_literal: true

module Crafty
  module Chords
    class EnactEvent
      # @return [nil, Crafty::ToolStateMachine::Mode] this can optionally be set to a non-`nil` value by
      #   the event handler to indicate that the
      attr_accessor :new_mode
    end # class EnactEvent

    class KeyPressEnactEvent < EnactEvent
      # @param handled [Boolean] the default state of the `handled` property
      def initialize(handled: true)
        @handled = handled
      end

      # @return [Boolean] `true` (the default) if the input was handled and SketchUp should ignore it; `false` to
      #   indicate that SketchUp should also process the keypress.
      attr_accessor :handled
    end # class KeyPressEnactEvent

    class ClickEnactEvent < EnactEvent
      # @param point [Geom::Point2d] the point where the mouse was clicked
      def initialize(point)
        @point = point
      end

      # @return [Geom::Point2d] the point where the mouse was clicked
      attr_reader :point
    end # class ClickEnactEvent

    class DragEnactEvent < EnactEvent
      # @param start_point [Geom::Point2d] the coordinate where the user started dragging
      # @param end_point [Geom::Point2d] the coordinate where the user ended dragging
      def initialize(start_point, end_point)
        @bounds = Util.bounds_from_pts start_point, end_point
        @direction = end_point.x >= start_point.x ? :left_to_right : :right_to_left
      end

      # @return [Geom::Bounds2d] the bounds of the rectangle dragged by the user
      attr_reader :bounds

      # @return [Symbol] `:left_to_right` if the user started drawing the rectangle on the
      #   left side and `:right_to_left` otherwise.
      attr_reader :direction
    end # DragEnactEvent
  end # module Chords
end # module Crafty
