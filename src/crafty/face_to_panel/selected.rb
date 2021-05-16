require 'sketchup.rb'
require 'crafty/tool_state_machine.rb'
require 'crafty/face_to_panel/targeting.rb'
require 'crafty/face_to_panel/tool.rb'

module Crafty
  module FaceToPanel
    class Selected < Crafty::ToolStateMachine::Mode
      @@last_thickness = nil

      # @param face [Sketchup::Face] the face to turn into a panel
      def initialize(face)
        @face = face
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
        self.set_thickness tool, view, @@last_thickness
        @input_pt = Sketchup::InputPoint.new @face.bounds.center

        center_screen_pos = view.screen_coords @face.bounds.center
        @input_pt.pick view, center_screen_pos.x, center_screen_pos.y

        tool.get_bounds.clear.add @face.bounds
        tool.get_bounds.add @input_pt.position unless @input_pt.position.nil?

        Sketchup.vcb_label = 'Panel thickness'
      end

      def on_mouse_move(tool, flags, x, y, view)
        if @input_pt.pick view, x, y
          projected_point = @input_pt.position.project_to_line [@face.bounds.center, @face.normal]
          angle = @face.normal.angle_between(projected_point - @face.bounds.center)
          self.set_thickness(tool, view, ((angle >= Math::PI ? -1 : 0) * (projected_point.distance @face.bounds.center)).to_l)
        end
        return self
      end

      def on_value(tool, text, view)
        begin
          thickness = text.to_l
          thickness = (-1 * thickness).to_l if thickness > 0
          self.set_thickness tool, view, thickness
        rescue ArgumentError
          view.tooltip = 'Invalid thickness'
          UI.beep
          return self
        else
          return self.on_return tool, view
        end
      end

      def on_return(tool, view)
        unless @cur_thickness.nil? or @cur_thickness == 0
          @@last_thickness = @cur_thickness
          return Targeting::new @face, @cur_thickness
        else
          UI.beep
          return self
        end
      end

      def draw(tool, view)
        FaceToPanel.highlight_face @face, view, "red", 2
        view.draw_points @face.bounds.center + self.get_offset_vector, 10, 1, "blue"
        unless @cur_thickness.nil? or @cur_thickness == 0
          FaceToPanel.highlight_face @face, view, "blue", 1, "-", self.get_offset_vector
          view.tooltip = "#{@cur_thickness.to_s} - #{@input_pt.tooltip}"
        else
          view.tooltip = @input_pt.tooltip
        end
        @input_pt.draw view
        true
      end

      private

      # @param tool [Crafty::ToolStateMachine::Tool] the tool to update
      # @param view [Sketchup::View] the active view
      # @param thickness [Length, nil] the new value for thickness
      def set_thickness tool, view, thickness
        if @cur_thickness.nil? || thickness != @cur_thickness
          @cur_thickness = thickness
          tool.get_bounds.add @face.bounds.center + self.get_offset_vector
          view.invalidate
          Sketchup.vcb_value = @cur_thickness
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
  end # module FaceToPanel
end # module Crafty
