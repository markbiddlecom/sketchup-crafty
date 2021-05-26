# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/chord.rb'

module Crafty
  module ToolStateMachine
    class Mode
      EMPTY_CHORDSET = Crafty::Chordset.new
      NULL_VCB_STATE = [false, '', ''].freeze
      CLICK_SLOP_DISTANCE = 5

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

      # @return [Array(Boolean, String, String)] describes the state of the VCB (measurement box) that should be shown:
      #   the first element defines whether the box is enabled for user input; the second is the box's description to
      #   display to the user, and the final element is the value to display in the box.
      def vcb
        NULL_VCB_STATE
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
      # rubocop:disable Naming/MethodName

      # @return [Proc] a block that returns the initial [Mode] for the tool.
      attr :activator

      # @return [Geom::BoundingBox] the bounding box containing the points of interest to the tool
      attr :bounds

      # @yield [] a block that is called whenever the tool is activated
      # @yieldreturn [Mode] the initial state for the tool
      def initialize(&activator)
        @activator = activator
        @bounds = Geom::BoundingBox.new
        @vcb_mode = Mode::NULL_VCB_STATE
        @status_text = ''
        @drag_rect = nil
      end

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
          if cur_pt.distance(@lbutton_down) <= CLICK_SLOP_DISTANCE
            if @mode.return_on_l_click
              self.apply_mode (@mode.on_return self, view), view
            else
              self.apply_mode (@mode.on_l_click self, flags, dx, dy, view), view
            end
            self.apply_mode @mode.chordset.on_click(Crafty::Chord::LBUTTON)
          end
        end
        @lbutton_down = nil
      end

      # @param view [Sketchup::View]
      def onRButtonUp(_flags, x, y, _view)
        unless @rbutton_down.nil?
          cur_pt = Geom::Point2d.new x, y
          if cur_pt.distance(@lbutton_down) <= CLICK_SLOP_DISTANCE
            @mode.chordset.on_click(Crafty::Chord::RBUTTON)
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
          if cur_pt.distance(down_pos) > CLICK_SLOP_DISTANCE
            @drag_rect = Geom::Bounds2d.new
          end
        end
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

      private

      # @param mode [Mode]
      # @param view [Sketchup::View]
      def apply_mode(mode, view = Sketchup.active_model.active_view)
        if mode != @mode
          @mode.deactivate_mode self, mode, view unless @mode.nil?
          mode.activate_mode self, @mode, view
          @mode = mode
        end
        self.update_ui
      end

      def update_ui(force = false)
        new_vcb = @mode.vcb
        if force || new_vcb != @vcb_mode
          @vcb_mode = new_vcb
          Sketchup.vcb_label = @vcb_mode[1]
          Sketchup.vcb_value = @vcb_mode[2]
        end
        new_status = @mode.status
        if force || new_status != @status_text
          @status_text = new_status
          Sketchup.status_text = new_status
        end
      end

      # rubocop:enable Naming/MethodName
    end # class Tool
  end # module ToolStateMachine
end # module Crafty
