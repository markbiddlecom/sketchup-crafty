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
    def self.apply(face, depth, offset, suppress_undo: false)
      return nil if face.nil?

      model = Sketchup.active_model
      Crafty::Util.wrap_with_undo('Face to Panel', suppress_undo) do
        group = Util.unsafe_copy_in_place(Sketchup.active_model.active_entities, face, group_name: 'Panel', wrap: false)
        group.transform! Geom::Transformation.translation(offset)

        faces_to_panelize = group.entities.grep(Sketchup::Face).map(&:persistent_id)
        faces_to_panelize.each { |id|
          cloned_face = model.find_entity_by_persistent_id(id)
          cloned_face.pushpull (-1 * depth.to_f).to_l unless cloned_face.nil? || cloned_face.deleted?
          # Look this up again in case the pushpull did something weird
          cloned_face = model.find_entity_by_persistent_id(id)
          Crafty::Util::Attributes.tag_primary_face cloned_face unless cloned_face.nil? || cloned_face.deleted?
        }
        panel_vector = face.normal.reverse.clone
        panel_vector.length = depth.to_l
        Util::Attributes.set_panel_vector group, panel_vector
        group
      end
    end
  end # module FaceToPanel
end # module Crafty
