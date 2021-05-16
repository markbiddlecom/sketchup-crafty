require 'sketchup.rb'
require 'crafty/consts.rb'
require 'crafty/tool_state_machine.rb'
require 'crafty/util.rb'
require 'crafty/face_to_panel/unselected.rb'
require 'crafty/face_to_panel/selected.rb'

module Crafty
  module FaceToPanel
    TOOL = Crafty::ToolStateMachine::Tool.new do
      # If a face is already selected, apply to that face; otherwise, ask the user to select a face
      sel = Sketchup.active_model.selection
      mode = Unselected.new
      if sel.length == 1 and sel[0].is_a? Sketchup::Face
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
    # @param depth [Geom::Length] the distance to extrude the face
    # @param offset [Geom::Vector3d] an offset to apply to all the verticies in `face`
    # @param suppress_undo [Boolean] set to `true` to disable this command being wraped in an operation
    # @return [Sketchup::Group, nil] the group containing the cloned and extruded face, or `nil` if the operation
    #   couldn't complete
    def self.apply(face, depth, offset, suppress_undo = false)
      return nil if face.nil?
      Crafty::Util.wrap_with_undo('Face to Panel', suppress_undo) do
        group = Sketchup.active_model.active_entities.add_group
        group.name = 'Panel'
        face = Crafty::Util.clone_face face, group.entities, offset
        face.pushpull depth
        return group
      end
    end

    # Uses view draw methods to draw a highlight for the given face
    # @param face [Sketchup::Face] the face to highlight
    # @param view [Sketchup::View] the view to use for drawing
    # @param color [String, Sketchup::Color] the color to draw the face in
    # @param stipple [String] the stipple pattern for the face
    # @param offset [Geom::Vector3d] an offset for the rendered face
    def self.highlight_face(face, view, color = "red", line_width = 5, stipple = "", offset = ZERO_VECTOR)
      view.drawing_color = color
      view.line_stipple = stipple
      view.line_width = line_width
      view.draw_polyline (Crafty::Util.loop_to_closed_pts face.outer_loop, offset)
      view.line_width = [1, line_width - 2].max
      face.loops[1...face.loops.length].each { |l|
        view.draw_polyline (Crafty::Util.loop_to_closed_pts l, offset)
      }
    end

  end # module FaceToPanel
end # module Crafty
