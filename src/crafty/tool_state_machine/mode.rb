# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/chord/chordset.rb'

module Crafty
  module ToolStateMachine
    class Mode
      EMPTY_CHORDSET = Crafty::Chords::Chordset.new
      NULL_VCB_STATE = [false, '', ''].freeze
      CLICK_SLOP_DISTANCE = 5

      # @return [Crafty::Chords::Chordset] the command chords applicable to this mode
      def chordset
        EMPTY_CHORDSET
      end

      # @return [Boolean] `true` if the tool should invoke {#on_return} when a simple left-click is detected, and
      #   `false` if it should invoke {#on_l_click} instead.
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
  end # module ToolStateMachine
end # module Crafty
