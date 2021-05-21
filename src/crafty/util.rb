require 'sketchup.rb'
require 'crafty/consts.rb'

module Crafty
  module Util
    # Utility method to quickly reload the tutorial files. Useful for development.
    # Can be run from Sketchup's ruby console via entering `Crafty::Util.reload`
    # @return [Integer] Number of files reloaded.
    def self.reload
      dir = __dir__.dup
      dir.force_encoding('UTF-8') if dir.respond_to?(:force_encoding)
      pattern = File.join(dir, '**/*.rb')
      Dir.glob(pattern).each { |file|
        # Cannot use `Sketchup.load` because its an alias for `Sketchup.require`.
        load file
      }.size
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
      rescue
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
      return (loop.vertices.map { |v| v.position + offset }) + [loop.vertices[0].position + offset]
    end

    # Copies the edges and faces for the given face element to the given group
    # @param face [Sketchup::Face] the face to clone
    # @param entities [Sketchup::Entities] the entities list to clone the face into
    # @param offset [Geom::Vector3d] an optional offset for all the face's vertices
    # @return [Sketchup::Face] the cloned face within `entities`
    def self.clone_face(face, entities, offset = ZERO_VECTOR)
      outer_face = entities.add_face (face.outer_loop.vertices.map { |v| v.position.offset(offset) })
      inner_faces = face.loops[1..face.loops.length].map { |inner_loop|
        entities.add_face (inner_loop.vertices.map { |v| v.position.offset(offset) } )
      }
      inner_faces.each { |face| face.erase! }
      return outer_face
    end

    # @param input [nil, String, Array<String>, Object, Array<Object>]
    # @return [Array<String>]
    def self.to_str_array(input = nil)
      if input.nil?
        return []
      elsif input.is_a? String
        return [input]
      elsif input.is_a? Array
        return input.map { |e| e.to_s }
      else
        return [input.to_s]
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
        return @modes[@cur_mode % @modes.length]
      end

      # Advances this cycle by the given amount
      # @param amount [Integer] the number of changes to apply to the cycle
      # @return [Cycle] this cycle instance, for method chaining or comparison
      def advance(amount = 1)
        @cur_mode += amount
        return self
      end

      # @param string_or_cycle [String, Cycle] the value to compare
      # @return [Boolean] `true` if both values currently represent cycles with the same current mode, and `false`
      #   otherwise.
      def ===(string_or_cycle)
        if string_or_cycle.is_a? String
          return self.cur_mode === string_or_cycle
        elsif string_or_cycle.is_a? Cycle
          return self.cur_mode === string_or_cycle.cur_mode
        else
          return false
        end
      end
    end
  end # module Util
end # module Crafty
