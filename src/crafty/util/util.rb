# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/consts.rb'
require 'crafty/util/construction.rb'
require 'crafty/util/geom.rb'

module Crafty
  module Util
    # Utility method to quickly reload the tutorial files. Useful for development.
    # Can be run from Sketchup's ruby console via entering `Crafty::Util.reload`
    # @return [String] a message describing the result of the reload
    def self.reload
      dir = Kernel.__dir__.dup
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

    # @param receiver [Object] the object that will receive method calls
    # @param target [Symbol, String]
    def self.method_ref(receiver, target)
      proc do |*args|
        receiver.__send__ target, *args
      end
    end

    # Pushes an undo operation with the given name and executes the block, committing the operation on success.
    # @param operation_name [String] the text to include in the Undo/Redo history
    # @param suppress [Boolean] set to true to cause the undo operation to be skipped
    # @param block the wrapped code to execute
    # @return [Object] the return value of the block
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

      # The tessellated triangles in a face's mesh can be smaller than SketchUp's tolerance threshold for modeling.
      # To handle this case, we'll apply a scale factor while we process and reverse that when we ungroup at the end.
      polygons, scale_factor = mesh_to_polygons_and_scale_factor mesh, TOLERANCE * 1.1, Plane.new(face.plane)
      transform, inverse_transform = operation_transforms(mesh.points[0], scale_factor)
      polygons.each do |polygon|
        temp_entities.add_face(*(polygon.map { |pt| transform * pt }))
      end

      # Now we've got a whole bunch of interior edges for the polygons that don't belong on the new face. So we'll
      # delete all the excess edges and call the remaining face(s) the result. There should generally only be one face
      # left over, but it depends on lots of things going right ;)
      temp_entities.erase_entities(
          temp_entities.grep(Sketchup::Edge).reject { |edge| edge.faces.size == 1 }
        )

      # Restore the original scale of the group points and explode it to drop all the faces into the desired entity list
      temp_group.transform! inverse_transform unless inverse_transform.identity?
      temp_group.transform! Geom::Transformation.translation(offset) unless offset.length == 0
      result = temp_group.explode
      result == false ? [] : result.grep(Sketchup::Face)
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
