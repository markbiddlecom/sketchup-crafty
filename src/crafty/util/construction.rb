# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/consts.rb'
require 'crafty/plane.rb'

module Crafty
  module Util
    # The minimum distance between points for them to be considered distinct by the `suggested_scale_factor` function.
    MIN_SCALE_SEPARATION = 1e-10.in

    # Determines whether a scaling operation should be applied to the given point set such that all points are
    # sufficiently separated to avoid tolerance-related issues.
    # @param pts [Enumerable<Geom::Point3d>] a set of points to check for proximity
    # @param tolerance [Length] the minimum desired distance between any two points in the list
    # @param plane [nil, Crafty::Plane] an optional plane along which point distances are tested
    # @return [nil, Numeric] the suggested scale factor to apply, or `nil` if scaling is not necessary
    def self.suggested_scale_factor(pts, tolerance = TOLERANCE, plane = nil)
      closest_dist = nil
      apply_closest = proc do |d|
        closest_dist = d if d > MIN_SCALE_SEPARATION && (closest_dist.nil? || d < closest_dist)
      end

      pts.each do |p1|
        p12d = plane.nil? ? nil : plane.project_2d(p1)
        pts.each do |p2|
          apply_closest.call(p1.distance(p2).to_f)
          next if plane.nil?

          # Compare the 2d distance as well as the distance on both the x and y axes
          p22d = plane.project_2d(p2)
          apply_closest.call(p12d.distance(p22d))
          apply_closest.call((p22d.x - p12d.x).abs)
          apply_closest.call((p22d.y - p12d.y).abs)
        end
      end
      t = tolerance.to_f
      if closest_dist < t
        t / closest_dist
      end
    end

    # Returns a list of the polygons within the given mesh and the result of maximizing the `suggested_scale_factor`
    # across each polygon
    # @param mesh [Geom::PolygonMesh] the mesh from which to extract and process polygons
    # @param tolerance [Length] the minimum desired distance between any two points in the list
    # @param plane [nil, Crafty::Plane] an optional plane along which point distances are tested
    # @return [Array(Array<Geom::Point3d>, Numeric)] a tuple containing the list of un-looped polygon points and the
    #   suggested scale factor. The scale factor will be `nil` if no triangles are below the tolerance threshold.
    def self.mesh_to_polygons_and_scale_factor(mesh, tolerance = TOLERANCE, plane = nil)
      polygons = mesh.polygons.map { |polygon| polygon.map { |index| mesh.point_at(index) } }
      scale_factor = (polygons.map { |polygon| suggested_scale_factor(polygon, tolerance, plane) }).reject(&:nil?).max
      [polygons, scale_factor]
    end

    # @param ctr [Geom::Point3d] the center-point for the scaling operation
    # @param factor [Numeric] the scaling factor to apply
    # @return [Array(Geom::Transformation, Geom::Transformation)] the transformation to apply prior and subsequent to
    #   the operation, respectively.
    #   @note if scaling is not necessary, both transformation's `identity?` method will return `true`.
    def self.operation_transforms(ctr, factor)
      if factor.nil?
        [IDENTITY, IDENTITY]
      else
        [Geom::Transformation.scaling(ctr, factor), Geom::Transformation.scaling(ctr, 1 / factor)]
      end
    end
  end # module Util
end # module Crafty
