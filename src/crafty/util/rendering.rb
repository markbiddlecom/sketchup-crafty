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

    # Uses `view` to draw a polyline after closing the given point loop
    # @param view [Sketchup::View] the view to use for rendering
    # @param open_gl_num [Integer] describes the intention of the `points` list; see `Sketchup::View.draw`
    # @param points [Array<Geom::Point3d>] the ordered points describing the polygon's edge
    # @param color [String, Sketchup::Color] the color of the drawn lines
    # @param width [Integer] the width of the drawn lines
    # @param stipple [String] the stipple pattern of the drawn lines
    # @param offset [Geom::Vector3d] an offset for the rendered face; ignored if `transform` is `nil`
    # @param transform [Geom::Transformation] an optional transformation to apply to the points before rendering; if
    #   not `nil`, `offset` is ignored
    # @param overlaid [Boolean] `true` to d
    # @param overlaid [Boolean] `true` to draw the face in the 2d plane (after mapping vertices), and `false` to draw
    #   in the 3d view
    # @param close [Boolean] `true` to draw a final line from the last point in `points` to the first, and `false` to
    #   draw the points as-is
    def self.draw(view, open_gl_num, *points,
        color: 'black', width: 1, stipple: STIPPLE_SOLID, offset: ZERO_VECTOR, transform: nil, overlaid: false,
        close: false)
      transform = Geom::Transformation.translation(offset) if transform.nil?
      pts_to_draw =
          (points + (close ? [points[0]] : [])) # close the loop if requested
          .map { |pt| transform * pt } # apply the transformation
      draw_and_restore(view, color: color, width: width, stipple: stipple) {
        if overlaid
          view.draw2d(open_gl_num, pts_to_draw.map { |pt| view.screen_coords(pt) })
        else
          view.draw(open_gl_num, pts_to_draw)
        end
      }
    end

    # Uses view draw methods to draw a highlight for the given face
    # @param face [Sketchup::Face] the face to highlight
    # @param view [Sketchup::View] the view to use for drawing
    # @param color [String, Sketchup::Color] the color to draw the face in
    # @param width [Integer] the line width to use when drawing
    # @param stipple [String] the stipple pattern for the face
    # @param offset [Geom::Vector3d] an offset for the rendered face; ignored if `transform` is `nil`
    # @param transform [Geom::Transformation] an optional transformation to apply to the points before rendering; if
    #   not `nil`, `offset` is ignored
    # @param overlaid [Boolean] `true` to draw the face in the 2d plane (after mapping vertices), and `false` to draw
    #   in the 3d view
    def self.highlight_face(face, view,
        color: 'red', width: 1, stipple: STIPPLE_SOLID, offset: ZERO_VECTOR, transform: nil, overlaid: false)
      draw(
          view,
          GL_LINE_LOOP,
          *face.outer_loop.vertices.map(&:position),
          color: color, width: width, stipple: stipple, offset: offset, transform: transform, overlaid: overlaid
        )
      view.line_width = [1, width - 2].max
      face.loops[1...face.loops.length].each { |l|
        draw(
            view,
            GL_LINE_LOOP,
            *l.vertices.map(&:position),
            color: color, width: width, stipple: stipple, offset: offset, transform: transform, overlaid: overlaid
          )
      }
    end

    # @param bounds [Geom::BoundingBox] the bounds to highlight
    # @param view [Sketchup::View] the view to use for drawing
    # @param color [String, Sketchup::Color] the color to draw the bounding box with
    # @param width [Integer] the line width to use when drawing
    # @param stipple [String] the stipple pattern for the box's edges
    # @param offset [Geom::Vector3d] an offset for the rendered box
    def self.highlight_bounds(bounds, view, color: 'blue', width: 3, stipple: STIPPLE_SOLID, offset: ZERO_VECTOR)
      x_min, y_min, z_min = bounds.corner(0).offset(offset).to_a
      x_max, y_max, z_max = bounds.corner(7).offset(offset).to_a
      # Top square
      draw(
          view,
          GL_LINE_STRIP,
          Geom::Point3d.new(x_min, y_min, z_max),
          Geom::Point3d.new(x_max, y_min, z_max),
          Geom::Point3d.new(x_max, y_max, z_max),
          Geom::Point3d.new(x_min, y_max, z_max),
          color: color, width: width, stipple: stipple
        )
      # Bottom square
      draw(
          view,
          GL_LINE_STRIP,
          Geom::Point3d.new(x_min, y_min, z_min),
          Geom::Point3d.new(x_max, y_min, z_min),
          Geom::Point3d.new(x_max, y_max, z_min),
          Geom::Point3d.new(x_min, y_max, z_min),
          color: color, width: width, stipple: stipple, close: true
        )
      # Legs
      draw(
          view,
          GL_LINES,
          Geom::Point3d.new(x_min, y_min, z_max), Geom::Point3d.new(x_min, y_min, z_min),
          Geom::Point3d.new(x_max, y_min, z_max), Geom::Point3d.new(x_max, y_min, z_min),
          Geom::Point3d.new(x_max, y_max, z_max), Geom::Point3d.new(x_max, y_max, z_min),
          Geom::Point3d.new(x_min, y_max, z_max), Geom::Point3d.new(x_min, y_max, z_min),
          color: color, width: width, stipple: stipple
        )
    end
  end # module Util
end # module Crafty
