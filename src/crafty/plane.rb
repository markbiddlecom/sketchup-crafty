# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/consts.rb'

module Crafty
  # Adapted from https://github.com/skotekar/flattery/blob/master/flattery/utils.rb
  # Represents the plane given by @normal (dot) x = @distance
  class Plane
    attr_reader :normal, :distance

    # @param plane_array [Array(Numeric, Numeric, Numeric, Numeric)] the plane defined as four coefficients
    def initialize(plane_array)
      @normal = Geom::Vector3d.new(plane_array.slice(0, 3))
      @distance = -plane_array[3] / @normal.length
      @normal.normalize!
    end

    # @return [Geom::Vector3d] a vector along the plane that represents the plane's "up" or u-axis
    def unit_vector
      if @unit.nil?
        sketch_plane_up = Geom::Vector3d.new(1, 0, 0)
        transform = XZ_PLANE.transformation_to(self)
        @unit = transform * sketch_plane_up
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

    # @return [Geom::Transformation] a transformation that will convert a given point on this plane to 2d coordinates
    #   (coordinates without a z component)
    def affine_transform
      if @affine_transform.nil?
        # https://stackoverflow.com/a/49771112
        pt_a = ORIGIN.offset @normal, @distance
        pt_u = pt_a.offset self.unit_vector
        pt_v = pt_a.offset self.base_vector
        pt_n = pt_a.offset @normal

        d_matrix = Geom::Transformation.new([0, 1, 0, 0,
                                             0, 0, 1, 0,
                                             0, 0, 0, 1,
                                             1, 1, 1, 1,])
        s_matrix = Geom::Transformation.new([pt_a.x, pt_u.x, pt_v.x, pt_n.x,
                                             pt_a.y, pt_u.y, pt_v.y, pt_n.y,
                                             pt_a.z, pt_u.z, pt_v.z, pt_n.z,
                                             1,      1,      1,      1,])

        @affine_transform = d_matrix * s_matrix.inverse
      end
      @affine_transform
    end

    # @return [Array(Numeric, Numeric, Numeric, Numeric)] this plane defined as four coefficients describing the vector
    #   from the origin and distance along that vector
    def to_a
      [@normal.x, @normal.y, @normal.z, -@distance]
    end

    # @param other [Plane] the plane to test against this plane
    # @return [Boolean] `true` if these planes are parallel and `false` otherwise
    def parallel?(other)
      @normal.parallel? other.normal
    end

    # @param pt3d [Geom::Point3d] the point whose 2d position along this plane
    # @return [Geom::Point2d]
    def project_2d(pt3d)
      transformed = self.affine_transform * pt3d
      Geom::Point2d.new(transformed.x, transformed.y)
    end

    # Applies the given transformation to this plane
    # @param transformation [Geom::Transformation] the transformation to apply
    def transform!(transformation)
      point = @normal.clone
      point.length = @distance
      point = ORIGIN + point
      point.transform!(transformation)
      point = ORIGIN.vector_to(point)

      @normal.transform!(transformation)
      @normal.normalize!
      @distance = point.dot(@normal)

      @unit = nil
      @base_vector = nil
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
      if vec.x.abs >= vec.y.abs && vec.x.abs >= vec.z.abs
        # solve with x=0
        px = 0
        py = (othr_n.z * @distance - this_n.z * other.distance) / (this_n.y * othr_n.z - othr_n.y * this_n.z)
        pz = (othr_n.y * @distance - this_n.y * other.distance) / (this_n.z * othr_n.y - othr_n.z * this_n.y)
      elsif vec.y.abs >= vec.z.abs
        # solve with y=0
        px = (othr_n.z * @distance - this_n.z * other.distance) / (this_n.x * othr_n.z - othr_n.x * this_n.z)
        py = 0
        pz = (othr_n.x * @distance - this_n.x * other.distance) / (this_n.z * othr_n.x - othr_n.z * this_n.x)
      else
        # solve with z=0
        px = (othr_n.y * @distance - this_n.y * other.distance) / (this_n.x * othr_n.y - othr_n.x * this_n.y)
        py = (othr_n.x * @distance - this_n.x * other.distance) / (this_n.y * othr_n.x - othr_n.y * this_n.x)
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
end # module Crafty
