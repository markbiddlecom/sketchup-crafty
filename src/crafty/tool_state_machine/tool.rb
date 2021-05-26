# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/chord.rb'
require 'crafty/tool_state_machine/tool_life_cycle.rb'

module Crafty
  module ToolStateMachine
    class Tool
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
    end # class Tool
  end # module ToolStateMachine
end # module Crafty
