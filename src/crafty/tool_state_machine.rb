# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/chord.rb'

module Crafty
  module ToolStateMachine
    class Mode
      EMPTY_CHORDSET = Crafty::Chordset.new

      # @return [Crafty::Chordset] the command chords applicable to this mode
      def chordset
        EMPTY_CHORDSET
      end

      # @return [Boolean] `true` if the tool should invoke {#on_return} when a simple left-click is detected, and
      #   `false` if it should invoke {#on_l_click} instead.
      def return_on_l_click
        false
      end

      # @return [String, nil] the message that should be visible in the Sketchup UI's status bar.
      def status
        nil
      end

      # @return [Boolean] `true` to enable the measurement bar and `false` otherwise.
      def enable_vcb?
        false
      end

      # @param tool [Tool]
      # @param old_mode [nil, Mode]
      # @param view [Sketchup::View]
      def activate_mode(tool, old_mode, view); end

      # @param tool [Tool]
      # @param new_mode [Mode]
      # @param view [Sketchup::View]
      def deactivate_mode(tool, new_mode, view); end

      # @param tool [Tool]
      # @param view [Sketchup::View]
      # @return [Mode] the mode for the next operation
      def on_mouse_move(_tool, _flags, _x, _y, _view)
        self
      end

      # @param tool [Tool]
      # @param view [Sketchup::View]
      # @return [Mode] the mode for the next operation
      def on_l_click(_tool, _flags, _x, _y, _view)
        self
      end

      # @param tool [Tool]
      # @param view [Sketchup::View]
      # @return [Mode] the mode for the next operation
      def on_return(_tool, _view)
        self
      end

      # @param tool [Tool]
      # @param text [String]
      # @param view [Sketchup::View]
      # @param [Mode] the mode for the next operation
      def on_value(_tool, _text, _view)
        self
      end

      # @param tool [Tool]
      # @param view [Sketchup::View]
      # @param return [Boolean] `true` if the view should be invalidated, and `false` otherwise
      def draw(_tool, _view)
        false
      end
    end # class Mode

    class Tool
      # rubocop:disable Naming/MethodName, Naming/AccessorMethodName

      # @return [Proc] a block that returns the initial [Mode] for the tool.
      attr :activator

      # @return [Geom::BoundingBox] the bounding box containing the points of interest to the tool
      def get_bounds
        @bounds
      end

      # @yield [] a block that is called whenever the tool is activated
      # @yieldreturn [Mode] the initial state for the tool
      def initialize(&activator)
        @activator = activator
        @bounds = Geom::BoundingBox.new
      end

      # Called by Sketchup when the tool is activated for the first time.
      def activate
        self.apply_mode @activator.call
      end

      # @param view [Sketchup::View]
      def onCancel(_reason, view)
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
        self.update_status
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, _view)
        @lbutton_down = [x, y]
      end

      def onRButtonDown(_flags, x, y, _view)
        @rbutton_down = [x, y]
      end

      # @param view [Sketchup::View]
      def onLButtonUp(flags, x, y, view)
        unless @lbutton_down.nil?
          dx, dy = @lbutton_down
          if (dx - x).abs + (dy - y).abs < 5
            if @mode.return_on_l_click
              self.apply_mode (@mode.on_return self, view), view
            else
              self.apply_mode (@mode.on_l_click self, flags, dx, dy, view), view
            end
            @mode.chordset.on_click(Crafty::Chord::LBUTTON)
          end
        end
        @lbutton_down = nil
        self.update_status
      end

      # @param view [Sketchup::View]
      def onRButtonUp(_flags, x, y, _view)
        unless @rbutton_down.nil?
          dx, dy = @rbutton_down
          if (dx - x).abs + (dy - y).abs < 5
            self.update_status if @mode.chordset.on_click(Crafty::Chord::RBUTTON)
          end
        end
        @rbutton_down = nil
      end

      # @param view [Sketchup::View]
      def onMouseMove(flags, x, y, view)
        self.apply_mode (@mode.on_mouse_move self, flags, x, y, view), view
        self.update_status
      end

      # @param view [Sketchup::View]
      def onKeyDown(key, repeat, _flags, _view)
        if repeat == 1
          self.update_status if @mode.chordset.on_keydown(key)
        end
      end

      # @param view [Sketchup::View]
      def onKeyUp(key, repeat, _flags, _view)
        if repeat == 1
          self.update_status if @mode.chordset.on_keyup(key)
        end
      end

      # @param view [Sketchup::View]
      def draw(view)
        view.invalidate if @mode.draw self, view
      end

      # @param view [Sketchup::View]
      def onReturn(view)
        self.apply_mode (@mode.on_return self, view), view
        self.update_status
      end

      def onUserText(text, view)
        self.apply_mode (@mode.on_value self, text, view), view
        self.update_status
      end

      def getExtents
        @bounds
      end

      def enableVCB?
        @mode.enable_vcb?
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

      def update_status
        Sketchup.status_text = @mode.status
      end

      # rubocop:enable Naming/MethodName, Naming/AccessorMethodName
    end # class Tool
  end # module ToolStateMachine
end # module Crafty
