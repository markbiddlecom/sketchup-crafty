# frozen_string_literal: true

module Crafty
  module ProjectToPlane
    class SelectFace < ToolStateMachine::Mode
      # @param selection [Enumerable<Sketchup::Entity>] the entities that will be projected
      # @param switch_mode [ToolStateMachine::Mode] the mode that should be switched to when `Tab` is pressed
      def initialize(selection, switch_mode)
        @selection = selection
        @switch_mode = switch_mode
        # @type [nil, Sketchup::Face]
        @face = nil
        @chordset = Crafty::Chords::Chordset.new(
            {
              cmd: :select,
              help: 'Select Face',
              trigger: Chords::Chord::LBUTTON,
              on_trigger: Util.method_ref(self, :on_select),
            },
            {
              cmd: :switch,
              help: 'Define Plane Manually',
              trigger: Chords::Chord::TAB,
              on_trigger: Util.method_ref(self, :on_switch),
            }
          )
      end

      # @param event [Crafty::Chords::EnactEvent] details about the event
      def on_select(_chord, event)
        if @face.nil?
          UI.beep
        else
          Crafty::ProjectToPlane.project_edges_to_plane(@selection, Crafty::Util::Plane.new(@face.plane))
          event.new_mode = ToolStateMachine::Mode::END_OF_OPERATION
        end
      end

      # @param event [Crafty::Chords::EnactEvent] details about the event
      def on_switch(_chord, event)
        event.new_mode = @switch_mode
      end

      def status
        'Select the face defining the plane to project to.'
      end
    end # class SelectFace
  end # module ProjectToPlane
end # module Crafty
