require 'sketchup.rb'

module Crafty
  module Util

    # Utility method to quickly reload the tutorial files. Useful for development.
    # Can be run from SketchUp's ruby console via entering `Crafty::Util.reload`
    # @return [Integer] Number of files reloaded.
    def self.reload
      pattern = File.join(__dir__, '**/*.rb')
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
    def wrap_with_undo(operation_name, suppress = false, &block)
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
    def self.loop_to_closed_pts(loop, offset = Geom::Vector3d.new(0, 0, 0))
      return (loop.vertices.map { |v| v.position }) + [loop.vertices[0].position + offset]
    end

    # Copies the edges and faces for the given face element to the given group
    # @param face [Sketchup::Face] the face to clone
    # @param entities [Sketchup::Entities] the entities list to clone the face into
    # @param offset [Geom::Vector3d] an optional offset for all the face's vertices
    # @return [Sketchup::Face] the cloned face within `entities`
    def self.clone_face(face, entities, offset = Geom::Vector3d.new(0, 0, 0))
      outer_face = entities.add_face (face.outer_loop.vertices.map { |v| v.position.offset(offset) })
      inner_faces = face.loops[1..face.loops.length].map { |inner_loop|
        entities.add_face (inner_loop.vertices.map { |v| v.position.offset(offset) } )
      }
      inner_faces.each { |face| face.erase! }
      return outer_face
    end

  end # module Util
end # module Crafty
