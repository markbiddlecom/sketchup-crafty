# frozen_string_literal: true

module Crafty
  module FaceToPanel
    class Selected < Crafty::ToolStateMachine::Mode
      @@last_thickness = nil

      # @param face [Sketchup::Face] the face to turn into a panel
      def initialize(face)
        @face = face
      end

      # @return [String]
      def status
        'Select a point to indicate panel thickness'
      end

      def vcb
        if @vector.nil?
          [false, 'Thickness', '']
        else
          [true, 'Thickness', @vector.length]
        end
      end

      def return_on_l_click
        true
      end

      def activate_mode(tool, _old_mode, view)
        ctr = @face.bounds.center
        pt2 = ctr
        if @@last_thickness.nil? || @@last_thickness == ZERO_LENGTH
          @vector = nil
        else
          pt2 = ctr.offset(@face.normal, @@last_thickness)
          @vector = ctr.vector_to pt2
        end
        @inference_ip = Sketchup::InputPoint.new ctr
        @thickness_ip = Sketchup::InputPoint.new pt2

        self.apply_bounds(tool)

        view.invalidate
      end

      def on_suspend(_tool, view)
        view.lock_inference # clear inferences
        self
      end

      def on_resume(_tool, view)
        self.lock_inference(view)
        self
      end

      def on_mouse_move(tool, _flags, x, y, view)
        if @thickness_ip.pick view, x, y, @inference_ip
          @vector = @face.bounds.center.vector_to @thickness_ip.position
          self.apply_bounds(tool)
          view.invalidate
        end
        self
      end

      def on_value(tool, text, view)
        thickness = text.to_l
        thickness = (-1 * thickness.to_f).to_l if thickness > 0.to_l
        @vector = @face.normal
        @vector.length = thickness.to_f
      rescue ArgumentError
        view.tooltip = 'Invalid thickness'
        UI.beep
        self
      else
        self.on_return tool, view
      end

      def on_return(_tool, _view)
        if @vector.nil? || @vector.length == 0.to_l
          UI.beep
          self
        else
          @@last_thickness = @vector.length
          Targeting.new @face, @vector.length
        end
      end

      def draw(_tool, view)
        view.draw_points @face.bounds.center, 10, 1, 'blue'
        Util.highlight_face @face, view, width: 3
        unless @vector.nil? || @vector.length == ZERO_LENGTH
          Util.highlight_face @face, view, width: 5, color: 'blue', stipple: Util::STIPPLE_DASHED, offset: @vector
          Util.draw_and_restore(view, stipple: Util::STIPPLE_DOTTED) {
            view.set_color_from_line @face.bounds.center, @thickness_ip.position
            # view.draw_line @face.bounds.center, @thickness_ip.position
          }
        end
        @thickness_ip.draw view
        view.tooltip = @thickness_ip.tooltip
      end

      private

      # @param view [Sketchup::View]
      # @return [void]
      def lock_inference(view)
        view.lock_inference # clear inference before resetting
        view.lock_inference @thickness_ip, Sketchup::InputPoint.new(@thickness_ip.position.offset(@face.normal))
      end

      # @param tool [ToolStateMachine::Tool] the tool whose bounds need to be set
      # @return [void]
      def apply_bounds(tool)
        tool.bounds.clear.add @face.bounds
        unless @vector.nil?
          tool.bounds.add @face.bounds.corner(0).offset(@vector), @face.bounds.corner(7).offset(@vector)
        end
      end
    end # class Selected
  end # module FaceToPanel
end # module Crafty
