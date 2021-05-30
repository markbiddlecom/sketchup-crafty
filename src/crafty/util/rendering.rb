# frozen_string_literal: true

module Crafty
  module Util
    STIPPLE_DOTTED = '.'
    STIPPLE_DASHED = '-'
    STIPPLE_LONG_DASHED = '_'
    STIPPLE_DASH_DOT = '-.-'
    STIPPLE_SOLID = ''

    # Executes the given block and then restores the default render settings
    # @param view [Sketchup::View] the view to control
    # @param width [Integer] the line width, in pixels
    # @param color [Sketchup::Color, String] the value to set `drawing_color` to
    # @param stipple [String] the stipple pattern to apply: `"."`, `"-"`, `"_"`, `"-.-"`, `""`
    # @return [void]
    def self.draw_and_restore(view, color: 'black', width: 1, stipple: STIPPLE_SOLID)
      view.drawing_color = color
      view.line_width = width
      view.line_stipple = stipple
      yield
    ensure
      view.line_stipple = STIPPLE_SOLID
      view.line_width = 1
      view.drawing_color = 'black'
    end

    # Uses view draw methods to draw a highlight for the given face
    # @param face [Sketchup::Face] the face to highlight
    # @param view [Sketchup::View] the view to use for drawing
    # @param color [String, Sketchup::Color] the color to draw the face in
    # @param width [Integer] the line width to use when drawing
    # @param stipple [String] the stipple pattern for the face
    # @param offset [Geom::Vector3d] an offset for the rendered face
    def self.highlight_face(face, view, color: 'red', width: 1, stipple: STIPPLE_SOLID, offset: ZERO_VECTOR)
      draw_and_restore(view, color: color, width: width, stipple: stipple) {
        view.draw_polyline(loop_to_closed_pts(face.outer_loop, offset))
        view.line_width = [1, width - 2].max
        face.loops[1...face.loops.length].each { |l|
          view.draw_polyline(loop_to_closed_pts(l, offset))
        }
      }
    end
  end # module Util
end # module Crafty
