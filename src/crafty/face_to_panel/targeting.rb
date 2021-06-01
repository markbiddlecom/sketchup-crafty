# frozen_string_literal: true

module Crafty
  module FaceToPanel
    class Targeting < Crafty::ToolStateMachine::Mode
      @@last_offset = ZERO_VECTOR

      # @param face [Sketchup::Face] the face to turn into a panel
      # @param thickness [Length] the thickness of the panel
      def initialize(face, thickness)
        @face = face
        @thickness = thickness
        @thickness_vector = @face.normal.reverse
        @thickness_vector.length = thickness.to_f
      end

      # @return [String]
      def status
        "Select a location for the panel's center point."
      end

      def vcb
        [true, 'Distance', @vector&.length&.to_s || '']
      end

      def return_on_l_click
        true
      end

      def activate_mode(tool, _old_mode, view)
        view.lock_inference # unlock all input point inferences
        view.invalidate

        ctr = @face.bounds.center
        pt2 = ctr.offset(@@last_offset)
        @vector = (@@last_offset || ZERO_VECTOR).clone
        @inference_ip = Sketchup::InputPoint.new ctr
        @offset_ip = Sketchup::InputPoint.new pt2

        self.apply_bounds tool
      end

      def on_mouse_move(tool, _flags, x, y, view)
        if @offset_ip.pick view, x, y, @inference_ip
          @vector = @face.bounds.center.vector_to @offset_ip.position
          self.apply_bounds tool
          view.invalidate
        end
        self
      end

      def on_value(tool, text, view)
        if @vector.length > ZERO_LENGTH
          begin
            @vector.length = text.to_l
            self.apply_bounds tool
            view.invalidate
          rescue ArgumentError
            view.tooltip = 'Invalid length'
            UI.beep
          else
            return self.on_return(tool, view)
          end
        else
          view.tooltip = 'Please indicate a direction before entering a length'
          UI.beep
        end
        self
      end

      def on_return(_tool, _view)
        @@last_offset = @vector || ZERO_VECTOR
        FaceToPanel.apply @face, @thickness, @@last_offset
        Sketchup.active_model.selection.clear
        Unselected.new
      end

      # @return [void]
      def draw(_tool, view)
        Util.highlight_face(@face, view, color: 'green', width: 2, offset: @vector)
        Util.highlight_face(@face, view, color: 'green', offset: @vector + @thickness_vector)

        Util.draw_and_restore(view, stipple: Util::STIPPLE_DOTTED) {
          view.set_color_from_line @face.bounds.center, @offset_ip.position
          view.draw_line @face.bounds.center, @offset_ip.position
        }

        @inference_ip.draw view
        @offset_ip.draw view
      end

      private

      # @param tool [ToolStateMachine::Tool] the tool whose bounds need to be set
      # @return [void]
      def apply_bounds(tool)
        tool.bounds.clear.add @face.bounds
        unless @vector.nil?
          tool.bounds.add @face.bounds.corner(0).offset(@vector), @face.bounds.corner(7).offset(@vector)
        end
      end
    end # class Targeting
  end # module FaceToPanel
end # module Crafty
