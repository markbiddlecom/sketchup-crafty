# frozen_string_literal: true

module Crafty
  module Util
    # Adapted from https://github.com/skotekar/flattery/blob/master/flattery/utils.rb
    # Represents the plane given by @normal (dot) x = @distance
    class Plane
      # @return [Geom::Vector3d] a normalized vector representing the orientation of the plane
      attr_reader :normal

      # @return [Length] the distance between the plane and the origin along the `normal` vector
      attr_reader :distance

      # @param plane_array [Array(Numeric, Numeric, Numeric, Numeric)] the plane defined as four coefficients
      def initialize(plane_array)
        @normal = Geom::Vector3d.new(plane_array.slice(0, 3))
        # @type [Length]
        @distance = (-plane_array[3] / @normal.length).to_l
        @normal.normalize!
      end

      # @return [Geom::Vector3d] a vector along the plane that represents the plane's "up" or u-axis
      def unit_vector
        if @unit.nil?
          sketch_plane_up = Geom::Vector3d.new(1, 0, 0)
          transform = XZ_PLANE.transformation_to(self)
          @unit = Geom::Vector3d.new(transform * sketch_plane_up)
        end
        @unit
      end

      # @return [Geom::Vector3d] a vector along the plane that is orthogonal to `unit_vector` and represents the plane's
      #   v-axis
      def base_vector
        if @base_vector.nil?
          @base_vector = self.unit_vector.cross(@normal)
        end
        @base_vector
      end

      # @return [Array(Numeric, Numeric, Numeric, Numeric)] this plane defined as four coefficients describing the
      #   vector from the origin and distance along that vector
      def to_a
        [@normal.x, @normal.y, @normal.z, -@distance.to_f]
      end

      # @param other [Plane] the plane to test against this plane
      # @return [Boolean] `true` if these planes are parallel and `false` otherwise
      def parallel?(other, either_orientation: false)
        @normal.parallel?(other.normal) || (either_orientation && @normal.parallel?(other.normal.reverse))
      end

      # @param other [Plane] the plane to test against this plane
      # @return [Boolean] `true` if these planes are equivalent and `false` otherwise
      def ==(other)
        if other.is_a?(Plane) && self.parallel?(other)
          # Distances have to be equivalent; invert distances if needed
          distance_factor = @normal.samedirection?(other.normal) ? 1.0 : -1.0
          @distance == (other.distance.to_f * distance_factor).to_l
        else
          false
        end
      end

      # @param pt3d [Geom::Point3d] the point whose 2d position along this plane
      # @return [Geom::Point2d]
      def project_2d(pt3d)
        # https://gamedev.stackexchange.com/questions/172352/finding-texture-coordinates-for-plane
        v = Geom::Vector3d.new pt3d.to_a
        Geom::Point2d.new self.unit_vector.dot(v), self.base_vector.dot(v)
      end

      # Applies the given transformation to this plane
      # @param transformation [Geom::Transformation] the transformation to apply
      # @return [Plane] this plane
      def transform!(transformation)
        point = @normal.clone
        point.length = @distance
        point = ORIGIN + point
        point.transform!(transformation)
        point = ORIGIN.vector_to(point)

        @normal.transform!(transformation)
        @normal.normalize!
        @distance = point.dot(@normal).to_l

        @unit = nil
        @base_vector = nil

        self
      end

      # @param other [Plane] the desired orientation
      # @return [Geom::Transformation] a transformation to apply to points on this plane in order to coerce them to
      #   the orientation of the given `other` plane
      def transformation_to(other)
        if self.parallel?(other)
          # TODO: If parallel but not coplanar, return a translation?  What about orientation?
          return Geom::Transformation.new
        end

        othr_n = other.normal
        this_n = @normal

        vec = this_n * othr_n
        vec.normalize!

        d = @distance.to_f
        d2 = other.distance

        if vec.x.abs >= vec.y.abs && vec.x.abs >= vec.z.abs
          # solve with x=0
          px = 0
          py = (othr_n.z * d - this_n.z * d2) / (this_n.y * othr_n.z - othr_n.y * this_n.z)
          pz = (othr_n.y * d - this_n.y * d2) / (this_n.z * othr_n.y - othr_n.z * this_n.y)
        elsif vec.y.abs >= vec.z.abs
          # solve with y=0
          px = (othr_n.z * d - this_n.z * d2) / (this_n.x * othr_n.z - othr_n.x * this_n.z)
          py = 0
          pz = (othr_n.x * d - this_n.x * d2) / (this_n.z * othr_n.x - othr_n.z * this_n.x)
        else
          # solve with z=0
          px = (othr_n.y * d - this_n.y * d2) / (this_n.x * othr_n.y - othr_n.x * this_n.y)
          py = (othr_n.x * d - this_n.x * d2) / (this_n.y * othr_n.x - othr_n.y * this_n.x)
          pz = 0
        end

        pt = Geom::Point3d.new(px, py, pz)

        angle_transform = Geom::Transformation.new(this_n, vec * this_n, vec, Geom::Point3d.new(0, 0, 0))
        angle_transform.invert!
        angle_vector = othr_n.transform(angle_transform)
        angle = Math.atan2(angle_vector.y, angle_vector.x)

        Geom::Transformation.new(pt, vec, angle)
      end
    end # class Plane
  end # module Util

  XZ_PLANE = Util::Plane.new([0, 1, 0, 0])
end # module Crafty
