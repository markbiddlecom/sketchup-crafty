# frozen_string_literal: true

module Crafty
  module ToolStateMachine
    class Mode
      EMPTY_CHORDSET = Chords::Chordset.new
      # @type [Array(Boolean, String, String)]
      NULL_VCB_STATE = [false, '', ''].freeze
      CLICK_SLOP_DISTANCE = 5

      # @return [Chords::Chordset] the command chords applicable to this mode
      def chordset
        EMPTY_CHORDSET
      end

      # @return [Boolean] `true` if the tool should invoke {#on_return} when a simple left-click is detected, instead of
      #   forwarding the command to the mode's chordset
      def return_on_l_click
        false
      end

      # @abstract
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
      # @return [void]
      def activate_mode(tool, old_mode, view); end

      # @param tool [Tool]
      # @param new_mode [Mode]
      # @param view [Sketchup::View]
      # @return [void]
      def deactivate_mode(tool, new_mode, view); end

      # @abstract
      # @param tool [Tool]
      # @param view [Sketchup::View]
      # @return [Mode] the mode for the next operation
      def on_suspend(_tool, _view)
        self
      end

      # @abstract
      # @param tool [Tool]
      # @param view [Sketchup::View]
      # @return [Mode] the mode for the next operation
      def on_resume(_tool, _view)
        self
      end

      # @param tool [Tool]
      # @param view [Sketchup::View]
      # @return [Mode] the mode for the next operation
      def on_mouse_move(_tool, _flags, _x, _y, _view)
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
      # @param return [void]
      def draw(_tool, _view); end
    end # class Mode

    class EndOfOperation < Mode
    end # class EndOfOperation

    class Mode
      # A special mode state that indicates a tool should be deactivated
      # @type [Mode]
      END_OF_OPERATION = EndOfOperation.new.freeze
    end # class Mode
  end # module ToolStateMachine
end # module Crafty
