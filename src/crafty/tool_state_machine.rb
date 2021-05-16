require "sketchup.rb"

module Crafty
  module ToolStateMachine
    class Mode
      # @return [Boolean] `true` if the tool should invoke {#on_return} when a simple left-click is detected, and
      #   `false` if it should invoke {#on_lclick} instead.
      def return_on_lclick
        false
      end

      # @return [String, nil] the message that should be visible in the Sketchup UI's status bar.
      def get_status
        return nil
      end

      # @return [Boolean] `true` to enable the measurement bar and `false` otherwise.
      def enable_vcb?
        false
      end

      # @param tool [Tool]
      # @param old_mode [nil, Mode]
      # @param view [Sketchup::View]
      def activate_mode(tool, old_mode, view)
      end

      # @param tool [Tool]
      # @param new_mode [Mode]
      # @param view [Sketchup::View]
      def deactivate_mode(tool, new_mode, view)
      end

      # @param tool [Tool]
      # @param view [Sketchup::View]
      # @return [Mode] the mode for the next operation
      def on_mouse_move(tool, flags, x, y, view)
        self
      end

      # @param tool [Tool]
      # @param view [Sketchup::View]
      # @return [Mode] the mode for the next operation
      def on_lclick(tool, flags, x, y, view)
        self
      end

      # @param tool [Tool]
      # @param view [Sketchup::View]
      # @return [Mode] the mode for the next operation
      def on_return(tool, view)
        self
      end

      # @param tool [Tool]
      # @param text [String]
      # @param view [Sketchup::View]
      # @param [Mode] the mode for the next operation
      def on_value(tool, text, view)
        self
      end

      # @param tool [Tool]
      # @param view [Sketchup::View]
      # @param return [Boolean] `true` if the view should be invalidated, and `false` otherwise
      def draw(tool, view)
        false
      end
    end # class Mode

    class Tool
      # @return [Proc] a block that returns the initial [Mode] for the tool.
      attr :activator

      # @return [Geom::BoundingBox] the bounding box containing the points of interest to the tool
      def get_bounds
        return @bounds
      end

      # @yield [] a block that is called whenever the tool is activated
      # @yieldreturn [Mode] the initial state for the tool
      def initialize &activator
        @activator = activator
        @bounds = Geom::BoundingBox.new
      end

      # Called by Sketchup when the tool is activated for the first time.
      def activate
        self.apply_mode @activator.call
      end

      # @param view [Sketchup::View]
      def onCancel(reason, view)
        Sketchup.active_model.select_tool nil
        view.invalidate
      end

      # @param view [Sketchup::View]
      def deactivate(view)
        view.invalidate
      end

      # @param view [Sketchup::View]
      def suspend(view)
        view.invalidate
      end

      # @param view [Sketchup::View]
      def resume(view)
        self.set_status
        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        @lbutton_down = [x, y]
      end

      # @param view [Sketchup::View]
      def onLButtonUp(flags, x, y, view)
        unless @lbutton_down.nil?
          dx, dy = @lbutton_down
          if (dx - x).abs + (dy - y).abs < 5
            if @mode.return_on_lclick
              self.apply_mode (@mode.on_return self, view), view
            else
              self.apply_mode (@mode.on_lclick self, flags, dx, dy, view), view
            end
          end
        end
        @lbutton_down = nil
        self.set_status
      end

      # @param view [Sketchup::View]
      def onMouseMove(flags, x, y, view)
        self.apply_mode (@mode.on_mouse_move self, flags, x, y, view), view
        self.set_status
      end

      # @param view [Sketchup::View]
      def draw(view)
        view.invalidate if @mode.draw self, view
      end

      # @param view [Sketchup::View]
      def onReturn(view)
        self.apply_mode (@mode.on_return self, view), view
        self.set_status
      end

      def onUserText(text, view)
        self.apply_mode (@mode.on_value self, text, view), view
        self.set_status
      end

      def getExtents
        return @bounds
      end

      def enableVCB?
        return @mode.enable_vcb?
      end

      private

      # @param mode [Mode]
      # @param view [Sketchup::View]
      def apply_mode(mode, view = Sketchup.active_model.active_view)
        if mode != @mode
          @mode.deactivate_mode self, mode, view unless @mode.nil?
          mode.activate_mode self, @mode, view
          @mode = mode
        end
      end

      def set_status
        Sketchup.status_text = @mode.get_status
      end
    end # class Tool
  end # module ToolStateMachine
end # module Crafty
