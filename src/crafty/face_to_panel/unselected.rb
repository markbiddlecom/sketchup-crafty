# frozen_string_literal: true

module Crafty
  module FaceToPanel
    class Unselected < Crafty::ToolStateMachine::Mode
      def status
        @status_text
      end

      def return_on_l_click
        true
      end

      def activate_mode(tool, _old_mode, _view)
        @status_text = 'Select the face to make into a panel'
        tool.get_bounds.clear
      end

      def on_mouse_move(tool, _flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick x, y
        self.face_to_pick = ph.picked_face
        if @face_to_pick.nil?
          view.tooltip = nil
        else
          view.tooltip = "Face in #{@face_to_pick.parent.respond_to?(:name) ? @face_to_pick.parent.name : 'model'}"
          tool.get_bounds.clear.add @face_to_pick.bounds
        end
        view.invalidate
        self
      end

      def on_return(_tool, _view)
        if @face_to_pick.nil?
          Sketchup.active_model.select_tool nil
          self
        else
          Sketchup.active_model.selection.clear
          Sketchup.active_model.selection.add @face_to_pick
          Selected.new @face_to_pick
        end
      end

      def draw(_tool, view)
        unless @face_to_pick.nil?
          FaceToPanel.highlight_face @face_to_pick, view
          true
        end
      end

      private

      # @param face [Sketchup::Face, nil] the face that is being picked
      attr_writer :face_to_pick
    end # class Unselected
  end # module FaceToPanel
end # module Crafty
