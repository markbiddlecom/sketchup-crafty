require 'sketchup.rb'
require 'crafty/tool_state_machine.rb'
require 'crafty/face_to_panel/tool.rb'
require 'crafty/face_to_panel/unselected.rb'

module Crafty
  module FaceToPanel
    class Unselected < Crafty::ToolStateMachine::Mode
      def get_status
        return @status_text
      end

      def return_on_lclick
        true
      end

      def activate_mode tool, old_mode, view
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
  end # module FaceToPanel
end # module Crafty
