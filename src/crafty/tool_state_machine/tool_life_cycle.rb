# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/tool_state_machine/tool.rb'

module Crafty
  module ToolStateMachine
    class Tool
      # rubocop:disable Naming/MethodName

      def getExtents
        @bounds
      end

      def enableVCB?
        @vcb_mode[0]
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
        @mode.chordset.reset!
      end

      # @param view [Sketchup::View]
      def suspend(view)
        view.invalidate
        @mode.chordset.reset!
      end

      # @param view [Sketchup::View]
      def resume(view)
        @mode.chordset.reset!
        self.update_ui true
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, _view)
        @lbutton_down = Geom::Point2d.new x, y
      end

      def onRButtonDown(_flags, x, y, _view)
        @rbutton_down = Geom::Point2d.new x, y
      end

      # @param view [Sketchup::View]
      def onLButtonUp(flags, x, y, view)
        unless @lbutton_down.nil?
          cur_pt = Geom::Point2d.new x, y
          if cur_pt.distance(@lbutton_down) <= Mode::CLICK_SLOP_DISTANCE
            if @mode.return_on_l_click
              self.apply_mode (@mode.on_return self, view), view
            else
              self.apply_mode (@mode.on_l_click self, flags, dx, dy, view), view
            end
            self.apply_mode @mode.chordset.on_click(Crafty::Chords::Chord::LBUTTON)
          end
        end
        @lbutton_down = nil
      end

      # @param view [Sketchup::View]
      def onRButtonUp(_flags, x, y, _view)
        unless @rbutton_down.nil?
          cur_pt = Geom::Point2d.new x, y
          if cur_pt.distance(@lbutton_down) <= Mode::CLICK_SLOP_DISTANCE
            @mode.chordset.on_click(Crafty::Chords::Chord::RBUTTON)
          end
        end
        @rbutton_down = nil
      end

      # @param view [Sketchup::View]
      def onMouseMove(flags, x, y, view)
        if @lbutton_down.nil? && @rbutton_down.nil?
          self.apply_mode (@mode.on_mouse_move self, flags, x, y, view), view
        else
          down_pos = @lbutton_down || @rbutton_down
          cur_pt = Geom::Point2d.new x, y
          if cur_pt.distance(down_pos) > Mode::CLICK_SLOP_DISTANCE
            @drag_rect = Geom::Bounds2d.new
          end
        end
      end

      # @param view [Sketchup::View]
      def onKeyDown(key, repeat, _flags, _view)
        if repeat == 1
          @mode.chordset.on_keydown(key)
        end
      end

      # @param view [Sketchup::View]
      def onKeyUp(key, repeat, _flags, _view)
        if repeat == 1
          @mode.chordset.on_keyup(key)
        end
      end

      # @param view [Sketchup::View]
      def draw(view)
        view.invalidate if @mode.draw self, view
      end

      # @param view [Sketchup::View]
      def onReturn(view)
        self.apply_mode (@mode.on_return self, view), view
      end

      def onUserText(text, view)
        self.apply_mode (@mode.on_value self, text, view), view
      end

      # rubocop:enable Naming/MethodName
    end # class Tool
  end # module ToolStateMachine
end # module Crafty
