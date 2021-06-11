# frozen_string_literal: true

module Crafty
  module Chords
    class EnactEvent
      # @return [nil, ToolStateMachine::Mode] this can optionally be set to a non-`nil` value by
      #   the event handler to indicate that the current tool mode should be changed
      attr_accessor :new_mode

      # @return [ToolStateMachine::Tool] the active tool
      attr_reader :tool

      # @return [Chords::Chordset] the chordset that triggered this event
      attr_reader :chordset

      # @return [Sketchup::View] the currently active view
      attr_reader :view

      # @param tool [ToolStateMachine::Tool] the active tool
      # @param chordset [Chordset] the chordset that triggered this event
      # @param view [Sketchup::View] the currently active view
      def initialize(tool, chordset, view)
        @tool = tool
        @chordset = chordset
        @view = view
      end
    end # class EnactEvent

    class KeyPressEnactEvent < EnactEvent
      # @param tool [ToolStateMachine::Tool] the active tool
      # @param chordset [Chordset] the chordset that triggered this event
      # @param view [Sketchup::View] the currently active view
      # @param handled [Boolean] the default state of the `handled` property
      def initialize(tool, chordset, view, handled: true)
        super(tool, chordset, view)
        @handled = handled
      end

      # @return [Boolean] `true` (the default) if the input was handled and SketchUp should ignore it; `false` to
      #   indicate that SketchUp should also process the keypress.
      attr_accessor :handled
    end # class KeyPressEnactEvent

    class ClickEnactEvent < EnactEvent
      # @param tool [ToolStateMachine::Tool] the active tool
      # @param chordset [Chordset] the chordset that triggered this event
      # @param view [Sketchup::View] the currently active view
      # @param point [Geom::Point2d] the point where the mouse was clicked
      def initialize(tool, chordset, view, point)
        super(tool, chordset, view)
        @point = point
      end

      # @return [Geom::Point2d] the point where the mouse was clicked
      attr_reader :point
    end # class ClickEnactEvent

    class DragEnactEvent < EnactEvent
      # @param tool [ToolStateMachine::Tool] the active tool
      # @param chordset [Chordset] the chordset that triggered this event
      # @param view [Sketchup::View] the currently active view
      # @param start_point [Geom::Point2d] the coordinate where the user started dragging
      # @param end_point [Geom::Point2d] the coordinate where the user ended dragging
      def initialize(tool, chordset, view, start_point, end_point)
        super(tool, chordset, view)
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
