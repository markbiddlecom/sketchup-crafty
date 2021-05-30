# frozen_string_literal: true

require 'crafty/face_to_panel/selected.rb'
require 'crafty/face_to_panel/targeting.rb'
require 'crafty/face_to_panel/unselected.rb'

module Crafty
  module FaceToPanel
    TOOL = Crafty::ToolStateMachine::Tool.new do
      # If a face is already selected, apply to that face; otherwise, ask the user to select a face
      sel = Sketchup.active_model.selection
      mode = Unselected.new
      if (sel.length == 1) && sel[0].is_a?(Sketchup::Face)
        mode = Selected.new sel[0]
      end
      mode
    end

    # Creates a new instance of the face to panel tool and gets it started
    def self.start_tool
      Sketchup.active_model.select_tool TOOL
    end

    # Creates a clone of the given face in its own group (within active_entities) and extrudes it to the given depth
    # @param face [Sketchup::Face] the face to clone and extrude
    # @param depth [Length] the distance to extrude the face
    # @param offset [Geom::Vector3d] an offset to apply to all the vertices in `face`
    # @param suppress_undo [Boolean] set to `true` to disable this command being wrapped in an operation
    # @return [Sketchup::Group, nil] the group containing the cloned and extruded face, or `nil` if the operation
    #   couldn't complete
    def self.apply(face, _depth, offset, suppress_undo = false)
      return nil if face.nil?

      Crafty::Util.wrap_with_undo('Face to Panel', suppress_undo) do
        group = Sketchup.active_model.active_entities.add_group
        group.name = 'Panel'
        faces = Crafty::Util.clone_face_geometry(face, group.entities, offset)
        faces.each { |cloned_face|
          Crafty::Util::Attributes.tag_primary_face cloned_face
          # cloned_face.pushpull depth
        }
        return group
      end
    end
  end # module FaceToPanel
end # module Crafty
