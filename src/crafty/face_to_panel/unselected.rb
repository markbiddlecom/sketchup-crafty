# frozen_string_literal: true

module Crafty
  module FaceToPanel
    class Unselected < ToolStateMachine::Mode
      # @return [String]
      def status
        'Select the face to make into a panel'
      end

      def return_on_l_click
        true
      end

      def on_resume(tool, view)
        tool.bounds.clear
        tool.bounds.add @face_to_pick.bounds unless @face_to_pick.nil?
        view.invalidate
        self
      end

      def on_mouse_move(tool, _flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick x, y
        # @type [Sketchup::Face]
        @face_to_pick = ph.picked_face

        if @face_to_pick.nil?
          view.tooltip = nil
        else
          view.tooltip = "Face in #{@face_to_pick.parent.respond_to?(:name) ? @face_to_pick.parent.name : 'model'}"
          tool.bounds.clear.add @face_to_pick.bounds
        end

        view.invalidate
        self
      end

      def on_return(_tool, _view)
        if @face_to_pick.nil?
          ToolStateMachine::Mode::END_OF_OPERATION
        else
          Sketchup.active_model.selection.clear
          Sketchup.active_model.selection.add @face_to_pick
          Selected.new @face_to_pick
        end
      end

      def draw(_tool, view)
        unless @face_to_pick.nil?
          Util.highlight_face @face_to_pick, view, width: 5
        end
      end
    end # class Unselected
  end # module FaceToPanel
end # module Crafty
