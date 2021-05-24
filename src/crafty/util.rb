# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/consts.rb'
require 'crafty/plane.rb'

module Crafty
  module Util
    # Utility method to quickly reload the tutorial files. Useful for development.
    # Can be run from Sketchup's ruby console via entering `Crafty::Util.reload`
    # @return [Integer] Number of files reloaded.
    def self.reload
      dir = __dir__.dup
      dir.force_encoding('UTF-8') if dir.respond_to?(:force_encoding)
      pattern = File.join(dir, '**/*.rb')
      old_verbose = $VERBOSE
      "Loaded #{
        (
          Dir.glob(pattern).each do |file|
            $VERBOSE = nil
            # Cannot use `Sketchup.load` because its an alias for `Sketchup.require`.
            load file
          ensure
            $VERBOSE = old_verbose
          end
        ).size} file(s)"
    end

    # Pushes an undo operation with the given name and executes the block, committing the operation on success.
    # @param operation_name [String] the text to include in the Undo/Redo history
    # @param suppress [Boolean] set to true to cause the undo operation to be skipped
    # @param block the wrapped code to execute
    # @return the return value of the block
    def self.wrap_with_undo(operation_name, suppress = false, &block)
      return block.call if suppress

      begin
        Sketchup.active_model.start_operation operation_name, true
        return block.call
      rescue StandardError
        Sketchup.active_model.abort_operation
        raise
      else
        Sketchup.active_model.commit_operation
      end
    end

    # Returns an array of [Geom::Point3d] values from the loop's vertices, with the first and last elements set to the
    # same vertex.
    # @param loop [Sketchup::Loop] the loop whose points are to be returned
    # @param offset [Geom::Vector3d] an offset to apply to each point
    # @return [Array<Geom::Point3d>] the points from the loop
    def self.loop_to_closed_pts(loop, offset = ZERO_VECTOR)
      (loop.vertices.map { |v| v.position + offset }) + [loop.vertices[0].position + offset]
    end

    # Explodes the given group and then returns a filtered list of entities that were added after the explosion.
    # @param parent_entities [Sketchup::Entities] the entities list the group is being exploded into.
    # @param group [Sketchup::Group] the group to explode.
    # @param block [nil, Proc] an optional block that is used to filter the returned list
    # @yield [entity] called for each entity from `parent_entities` that is new to that list following the explosion.
    # @yieldparam entity [Sketchup::Entity] an entity that was added by the explosion.
    # @yieldreturn [Boolean] `true` to include `entity` in the returned array, and `false` otherwise.
    # @return [Array<Sketchup::Entity>] the newly added and filtered entities.
    def self.entities_from_exploded_group(parent_entities, group, &block)
      block = proc { true } if block.nil?
      entities_before = parent_entities.to_set
      group.explode
      (parent_entities.to_set - entities_before).filter(&block)
    end

    # Determines whether a scaling operation should be applied to the given point set such that all points are
    # sufficiently separated to avoid tolerance-related issues.
    # @param pts [Enumerable<Geom::Point3d>] a set of points to check for proximity
    # @param tolerance [Length] the minimum desired distance between any two points in the list
    # @param plane [nil, Crafty::Plane] an optional plane along which point distances are tested
    # @return [nil, Numeric] the suggested scale factor to apply, or `nil` if scaling is not necessary
    def self.suggested_scale_factor(pts, tolerance = TOLERANCE, plane = nil)
      closest_dist = nil
      apply_closest = proc do |d|
        closest_dist = d if d > 0 && (closest_dist.nil? || d < closest_dist)
      end

      pts.each do |p1|
        p12d = plane.nil? ? nil : plane.project_2d(p1)
        pts.each do |p2|
          apply_closest.call(p1.distance(p2).to_f)
          next if plane.nil?

          # Compare the 2d distance as well as the distance on both the x and y axes
          p22d = plane.nil? ? nil : plane.project_2d(p2)
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

    # Returns a set of transformations that can be applied to `pts` before and after an operation such that no two
    # points are closer than `tolerance` to each other.
    # @param pts [Enumerable<Geom::Point3d>] a set of points to check for proximity
    # @param tolerance [Length] the minimum desired distance between any two points in the list
    # @param plane [nil, Crafty::Plane] an optional plane along which point distances are tested
    # @return [Array(Geom::Transformation, Geom::Transformation)] the transformation to apply prior and subsequent to
    #   the operation, respectively.
    #   @note if scaling is not necessary, both transformation's `identity?` method will return `true`.
    def self.operation_transforms(pts, tolerance = TOLERANCE, plane = nil)
      factor = suggested_scale_factor(pts, tolerance, plane)
      if factor.nil?
        [IDENTITY, IDENTITY]
      else
        # We could be fancy and try and pick the geometric center of the face, but this'll do fine. Not scaling about
        # the origin just to improve the debuggability of returned matrices
        ctr = pts.first
        [Geom::Transformation.scaling(ctr, factor), Geom::Transformation.scaling(ctr, 1 / factor)]
      end
    end

    # Copies the edges and faces for the given face element to the given entity list.
    # @note this does _not_ copy textures, attributes, or other information from the source face.
    # @param face [Sketchup::Face] the face to clone
    # @param entities [Sketchup::Entities] the entities list to clone the face into
    # @param offset [Geom::Vector3d] an optional offset for all the face's vertices
    # @return [Array<Sketchup::Face>] the cloned face(s) within `entities`; will generally be a single face
    def self.clone_face_geometry(face, entities, offset = ZERO_VECTOR)
      # Create a temporary group
      temp_group = entities.add_group
      temp_entities = temp_group.entities

      # Use the face's mesh to add a bunch of connected polygons (triangles) to the temporary group
      mesh = face.mesh

      # There are two things we need to correct for while working with faces.
      # 1. Faces can contain vertices that are not coplanar, such as after scaling the face up past its tolerance
      #    threshold. To fix that, we'll make sure to project points onto the face's plane as we process them.
      # 2. The tessellated triangles in a face's mesh can be smaller than SketchUp's tolerance threshold for modeling.
      #    To handle this case, we'll apply a scale factor while we process and reverse that when we ungroup at the end.
      transform, inverse_transform = operation_transforms(mesh.points, TOLERANCE * 1.1, Plane.new(face.plane))
      plane = transform * face.plane
      mesh.polygons.each do |polygon|
        transformed_points = polygon.map { |index| transform * (mesh.point_at(index) + offset) }
        projected_points = transformed_points.map { |pt| pt.project_to_plane(plane) }
        temp_entities.add_face(*projected_points)
      end

      # Now we've got a whole bunch of interior edges for the polygons that don't belong on the new face. So we'll
      # delete all the excess edges and call the remaining face(s) the result. There should generally only be one face
      # left over, but it depends on lots of things going right ;)
      temp_entities.erase_entities(
          temp_entities.grep(Sketchup::Edge).reject { |edge| edge.faces.size == 1 }
        )

      # Restore the original scale of the group points and explode it to drop all the faces into the desired entity list
      temp_group.transform! inverse_transform unless inverse_transform.identity?
      entities_from_exploded_group(entities, temp_group) { |entity| entity.is_a? Sketchup::Face }
    end

    # @param input [nil, String, Array<String>, Object, Array<Object>]
    # @return [Array<String>]
    def self.to_str_array(input = nil)
      if input.nil?
        []
      elsif input.is_a? String
        [input]
      elsif input.is_a? Array
        input.map(&:to_s)
      else
        [input.to_s]
      end
    end

    class Cycle
      # @param modes [Array<String>] the modes the cycle will iterate through
      def initialize(*modes)
        @modes = modes
        @cur_mode = 0
      end

      # @return [String] the current mode of this cycle.
      def cur_mode
        @modes[@cur_mode % @modes.length]
      end

      # Advances this cycle by the given amount
      # @param amount [Integer] the number of changes to apply to the cycle
      # @return [Cycle] this cycle instance, for method chaining or comparison
      def advance(amount = 1)
        @cur_mode += amount
        self
      end

      # @param string_or_cycle [String, Cycle] the value to compare
      # @return [Boolean] `true` if both values currently represent cycles with the same current mode, and `false`
      #   otherwise.
      def ===(string_or_cycle)
        if string_or_cycle.is_a? String
          self.cur_mode == string_or_cycle
        elsif string_or_cycle.is_a? Cycle
          self.cur_mode == string_or_cycle.cur_mode
        else
          false
        end
      end
    end
  end # module Util
end # module Crafty
