# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/tool_state_machine.rb'

module Crafty
  module ProjectToPlane
    class SelectFace < ToolStateMachine::Mode
      # @param selection [Array<Sketchup::Entity>] the entities that will be projected
      # @param switch_state [ToolStateMachine::Mode] the mode that should be switched to when `Tab` is pressed
      def initialize(selection, switch_state)
        @selection = selection
        @switch_state = switch_state
      end

      def status
        'Select the face defining the plane to project to.'
      end
    end # class SelectFace
  end # module ProjectToPlane
end # module Crafty
