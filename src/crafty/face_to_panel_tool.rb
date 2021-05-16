require 'sketchup.rb'
require 'crafty/consts.rb'
require 'crafty/tool_state_machine.rb'
require 'crafty/util.rb'

module Crafty
  module FaceToPanel
    module ToolMode
      class Unselected < Crafty::ToolStateMachine::Mode
        # @return [Sketchup::Face, nil] the face that will be picked
        attr :face_to_pick

        def get_status
          return @status_text
        end

        def activate_mode tool, old_mode
          @return_on_lclick = true
          @status_text = "Select the face to make into a panel"
          tool.get_bounds.clear
        end

        def on_mouse_move(tool, flags, x, y, view)
          ph = view.pick_helper
          ph.do_pick x, y
          self.set_face_to_pick ph.picked_face
          unless @face_to_pick.nil?
            view.tooltip = "Face in #{@face_to_pick.parent.respond_to? :name ? @face_to_pick.parent.name : "model"}"
            tool.get_bounds.clear.add @face_to_pick.bounds
          else
            view.tooltip = nil
          end
          view.invalidate
          return self
        end

        def on_return(tool, view)
          unless @face_to_pick.nil?
            Sketchup.active_model.selection.clear
            Sketchup.active_model.selection.add @face_to_pick
            return Selected.new @face_to_pick
          else
            Sketchup.active_model.select_tool nil
            return self
          end
          view.invalidate
        end

        def draw(tool, view)
          unless @face_to_pick.nil?
            FaceToPanel.highlight_face @face_to_pick, view
            return true
          end
        end

        private

        # @param face [Sketchup::Face, nil] the face that is being picked
        def set_face_to_pick face
          @face_to_pick = face
        end
      end # class Unselected

      class Selected < Crafty::ToolStateMachine::Mode
        @@last_thickness = nil

        # @param face [Sketchup::Face] the face to turn into a panel
        # @param view [Sketchup::View, nil] the active view, if known
        def initialize(face, view = nil)
          @face = face
        end

        def get_status
          return @status_text
        end

        def activate_mode(tool, old_mode, view)
          self.set_thickness tool, view, @@last_thickness
          @input_pt = Sketchup::InputPoint.new

          tool.get_bounds.clear.add @face.bounds
          tool.get_bounds.add @input_pt.position unless @input_pt.position.nil?
        end

        def on_mouse_move(tool, flags, x, y, view)
          if @input_pt.pick view, x, y
            projected_point = @input_pt.position.project_to_line [@face.bounds.center, @face.normal]
            angle = @face.normal.angle_between(projected_point - @face.bounds.center)
            self.set_thickness(tool, view, (angle >= Math.PI ? -1 : 0) * projected_point.distance, @face.bounds.center)
          end
          return self
        end

        def draw(view)
          FaceToPanel.highlight_face @face, view, "red", 3
          unless @cur_thickness.nil? or @cur_thickness == 0
            FaceToPanel.highlight_face @face, view, "blue", 3, ".", self.get_offset_vector
          end
          @input_pt.draw view
          true
        end

        private

        # @param tool [Crafty::ToolStateMachine::Tool] the tool to update
        # @param view [Sketchup::View] the active view
        # @param thickness [Length, nil] the new value for thickness
        def set_thickness tool, view, thickness
          if thickness != @cur_thickness
            @cur_thickness = thickness
            @@last_thickness = thickness
            tool.get_bounds.add @face.bounds.center + self.get_offset_vector
            view.invalidate
          end
        end

        # @return [Geom::Vector3d]
        def get_offset_vector
          if @cur_thickness.nil?
            return ZERO_VECTOR
          else
            normal = @face.normal.clone
            normal.length = @cur_thickness
            return normal
          end
        end
      end # class Selected
    end # module ToolMode

    # Creates a new instance of the face to panel tool and gets it started
    def self.start_tool
      Sketchup.active_model.select_tool Tool.new do
        # If a face is already selected, apply to that face; otherwise, ask the user to select a face
        sel = Sketchup.active_model.selection
        if sel.length == 1 and sel[0].is_a? Sketchup::Face
          return ToolMode::Selected.new sel[0]
        else
          sel.clear
          return ToolMode::Unselected.new
        end
        self.update_ui
      end
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
        group = Sketchup.active_entities.add_group
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
    def self.highlight_face(face, view, color = "red", line_width = 5, stipple = "", offset = Geom::Vector3d.new(0, 0, 0))
      view.drawing_color = color
      view.line_stipple = stipple
      view.line_width = line_width
      view.draw_polyline Crafty::Util.loop_to_closed_pts face.outer_loop, offset
      view.line_width = [1, line_width - 2].max
      face.loops[1...face.loops.length].each { |l|
        view.draw_polyline Crafty::Util.loop_to_closed_pts l
      }
    end

  end # module FaceToPanel
end # module Crafty
