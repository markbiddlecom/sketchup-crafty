require 'sketchup.rb'
require 'crafty/consts.rb'
require 'crafty/tool_state_machine.rb'
require 'crafty/face_to_panel/tool.rb'
require 'crafty/face_to_panel/unselected.rb'

module Crafty
  module FaceToPanel
    class Targeting < Crafty::ToolStateMachine::Mode
      @@last_offset = ZERO_VECTOR

      # @param face [Sketchup::Face] the face to turn into a panel
      # @param thickness [Length] the thickness of the panel
      def initialize(face, thickness)
        @face = face
        @thickness = thickness
        @thickness_vector = @face.normal.clone
        @thickness_vector.length = thickness
      end

      def get_status
        return @status_text
      end

      def enable_vcb?
        true
      end

      def return_on_lclick
        true
      end

      def activate_mode(tool, old_mode, view)
        Sketchup.vcb_label = 'Distance'
        @input_pt = Sketchup::InputPoint.new @face.bounds.center

        center_screen_pos = view.screen_coords @face.bounds.center
        @input_pt.pick view, center_screen_pos.x, center_screen_pos.y

        @status_text = "Select a location for the panel's centerpoint."
        self.set_offset @@last_offset, tool, view
      end

      def on_mouse_move(tool, flags, x, y, view)
        if @input_pt.pick view, x, y
          self.set_offset @input_pt.position - @face.bounds.center, tool, view
        end
        return self
      end

      def on_value(tool, text, view)
        if @offset.length == 0
          view.tooltip = 'Please indicate a movement direction first'
          return self
        end
        distance = 0
        begin
          distance = text.to_l
        rescue ArgumentError
          view.tooltip = 'Invalid length'
          UI.beep
          return self
        else
          new_target = @face.bounds.center.offset @offset, distance
          self.set_offset new_target - @face.bounds.center, tool, view
          return self.on_return tool, view
        end
      end

      def on_return(tool, view)
        @@last_offset = @offset
        FaceToPanel.apply @face, @thickness, @offset
        Sketchup.active_model.selection.clear
        return Unselected.new
      end

      def draw(tool, view)
        target = @face.bounds.center.offset(@offset)
        FaceToPanel.highlight_face @face, view, "green", 2, "", @offset
        FaceToPanel.highlight_face @face, view, "green", 1, "", @offset + @thickness_vector

        view.set_color_from_line @face.bounds.center, target
        view.line_width = 1
        view.line_stipple = "."
        view.draw_line @face.bounds.center, target

        @input_pt.draw view
        true
      end

      private

      # @param offset [Geom::Vector3d]
      # @param tool [Crafty::ToolStateMachine::Tool]
      # @param view [Sketchup::View]
      def set_offset(offset, tool, view)
        if @offset.nil? or @offset != offset
          @offset = offset
          Sketchup.vcb_value = offset.length
          view.invalidate
          tool.get_bounds.add @face.bounds.min.offset(offset)
          tool.get_bounds.add @face.bounds.max.offset(offset)
        end
      end
    end # class Targeting
  end # module FaceToPanel
end # module Crafty
