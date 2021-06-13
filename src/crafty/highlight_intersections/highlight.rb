# frozen_string_literal: true

module Crafty
  module HighlightIntersections
    class Highlight
      # @return [Integer] the persistent ID of the source group
      attr_reader :source_pid

      # @return [Integer] the persistent ID of the destination group
      attr_reader :target_pid

      # @return [Symbol] either `:penetrating` or `:abutting`
      attr_reader :type

      # @return [Geom::Vector3d] a vector that defines the axis along which a penetrating face should be
      #   segmented
      attr_reader :split_vector

      # @return [Array<Array<Geom::Point3d>>] a list of the loops for the given face
      attr_reader :loops

      # @return [Array<Array<Geom::Point3d>>] a list of polygons (typically triangles) that tesselate the face
      attr_reader :polygons

      # @return [Util::Plane] the plane defining this face
      attr_reader :plane

      # @return [ScreenBounds] the current screen bounds of this highlight, as of the last view calculation
      attr_reader :screen_bounds

      # @return [Array<Geom::Point3d, Geom::Point3d, Geom::Point3d, Boolean, Util::FuzzyNumeric>] an array containing
      #   the last known view camera settings: `[eye, target, up, perspective, fov]`, or `nil` if the camera has not
      #   been observed yet
      attr_reader :last_camera

      # @return [Boolean] whether or not this highlight is currently selected
      attr_accessor :selected

      # @param source [Sketchup::Group] the intersecting or abutting solid
      # @param target [Sketchup::Group] the solid that has been intersected or abutted
      # @param face [Sketchup::Face] the face describing the intersecting area
      # @param type [Symbol] the type of highlight this represents `:penetrating` or `:abutting`
      # @param face_transform [Geom::Transformation] a transformation to apply to the captured geometry
      def initialize(source, target, face, type, face_transform: IDENTITY)
        @source_pid = source.persistent_id
        @target_pid = target.persistent_id
        @type = type
        @split_vector = (Util::Attributes.get_panel_vector target)&.cross(face.normal)
        @plane = Util::Plane.new(face.plane).transform! face_transform

        @loops = face.loops.map { |l| l.vertices.map { |v| face_transform * v.position } }

        mesh = face.mesh
        @polygons = mesh.polygons.flat_map { |indices|
          indices.map { |index| face_transform * mesh.point_at(index.abs) }
        }

        @selected = false
      end

      # Updates `screen_bounds` to reflect the position of this highlight given the current state of the view
      # @param view [Sketchup::View] the current view coordinates
      def calculate_screen_bounds(view)
        @screen_bounds = ScreenBounds.new(view, @polygons)
      end

      # @param x [Numeric] the x coordinate to test
      # @param y [Numeric] the y coordinate to test
      # @param view [Sketchup::View] the current view
      # @return [Boolean] `true` if this highlight contains the given point, and `false` otherwise
      def contains?(x, y, view)
        # See if we need to recalculate bounds
        eye = view.camera.eye
        target = view.camera.target
        up = view.camera.up
        perspective = view.camera.perspective?
        fov = Util::FuzzyNumeric.new view.camera.fov
        camera = [eye, target, up, perspective, fov]

        if @last_camera.nil? || @last_camera != camera
          self.calculate_screen_bounds(view)
          @last_camera = camera
        end

        @screen_bounds.contains? x, y
      end
    end # class Highlight

    class ScreenBounds
      # @return [Geom::Bounds2d] the screen-oriented bounding box containing this face
      attr_reader :bounds

      # @return [Array<Array<Geom::Point2d>>] a collection of screen-space triangles that define this face
      attr_reader :screen_polygons

      # @param view [Sketchup::View] the current state of the view
      # @param world_polygons [Enumerable<Geom::Point3d>] a collection of the 3-point polygons defining this
      #   highlight
      def initialize(view, world_polygons)
        min_x = max_x = min_y = max_y = nil
        @screen_polygons = world_polygons.each_slice(3).map { |polygon|
          polygon.map { |pt|
            sp = view.screen_coords(pt)
            x, y = sp.to_a
            min_x = x if min_x.nil? || x < min_x
            max_x = x if max_x.nil? || x > max_x
            min_y = y if min_y.nil? || y < min_y
            max_y = y if max_y.nil? || y > max_y
            Geom::Point2d.new(x, y)
          }
        }
        @bounds = Geom::Bounds2d.new(Geom::Point2d.new(min_x, min_y), Geom::Point2d.new(max_x, max_y))
      end

      # @param x [Numeric] the x coordinate to test
      # @param y [Numeric] the y coordinate to test
      # @return [Boolean] `true` if the given point is contained in this highlight, and `false` otherwise
      def contains?(x, y)
        if x >= @bounds.upper_left.x && x <= @bounds.lower_right.x
          if y >= @bounds.upper_left.y && y <= @bounds.lower_right.y
            return @screen_polygons.any? { |polygon| self.polygon_contains?(x, y, polygon) }
          end
        end
        false
      end

      private

      # Cribbed from https://stackoverflow.com/a/2049593
      # @param x [Numeric]
      # @param y [Numeric]
      # @param pt2 [Geom::Point2d]
      # @param pt3 [Geom::Point2d]
      def sign(x, y, pt2, pt3)
        (x - pt3.x) * (pt2.y - pt3.y) - (pt2.x - pt3.x) * (y - pt3.y)
      end

      # Cribbed from https://stackoverflow.com/a/2049593
      # @param x [Numeric] the x coordinate to test
      # @param y [Numeric] tye y coordinate to test
      # @param polygon [Array<Geom::Point2d, Geom::Point2d, Geom::Point2d>] the polygon to test
      def polygon_contains?(x, y, polygon)
        v1, v2, v3 = polygon
        d1 = self.sign(x, y, v1, v2)
        d2 = self.sign(x, y, v2, v3)
        d3 = self.sign(x, y, v3, v1)

        has_neg = (d1 < 0) || (d2 < 0) || (d3 < 0)
        has_pos = (d1 > 0) || (d2 > 0) || (d3 > 0)

        !(has_neg && has_pos)
      end
    end # class ScreenLoop
  end # module HighlightIntersections
end # module Crafty
