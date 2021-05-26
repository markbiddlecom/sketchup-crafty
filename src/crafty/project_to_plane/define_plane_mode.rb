# frozen_string_literal: true

module Crafty
  module ProjectToPlane
    class DefinePlanePt1 < ToolStateMachine::Mode
      # @param selection [Enumerable<Sketchup::Entity>]
      # @param center_point [Geom::Point3d] the point that represents the center of the selection to project
      def initialize(selection, center_point)
        @selection = selection
        @center_point = center_point
        @chordset = Chords::Chordset.new(
            {
              cmd: :switch,
              help: 'Define Plane With Face',
              trigger: Chords::Chord::TAB,
              on_trigger: Util.method_ref(self, :on_switch),
            },
            {
              cmd: :select,
              help: 'Select Plane Origin Point',
              trigger: Chords::Chord::LBUTTON,
              on_trigger: Util.method_ref(self, :on_select),
            }
          )
      end

      # @param event [Chords::ClickEnactEvent] details about the event
      def on_select(_chord, event)
        if @vector.nil?
          UI.beep
        else
          event.new_mode = DefinePlanePt2.new
        end
      end

      # @param event [Chords::EnactEvent] details about the event
      def on_switch(_chord, event)
        event.new_mode = SelectFace.new(@selection, self)
      end

      def activate_mode(tool, _old_mode, view)
        @anchor_pt = Sketchup::InputPoint.new @center_point
        @input_pt = Sketchup::InputPoint.new @anchor_pt
        @vector = nil
        tool.bounds.clear.add(@center_point)
        view.invalidate
      end

      def vcb
        if @vector.nil?
          [false, 'Distance', '']
        else
          [true, 'Distance', @vector.length]
        end
      end

      def on_mouse_move(tool, _flags, x, y, view)
        if @input_pt.pick view, x, y, nil
          tool.bounds.add(@input_pt.position)
          @vector = @center_point.vector_to @input_pt.position
        else
          @vector = nil
        end
        view.invalidate
        self
      end

      def draw(_tool, view)
        @input_pt.draw view
        true
      end
    end

    class DefinePlanePt2 < ToolStateMachine::Mode
    end

    class DefinePlanePt3 < ToolStateMachine::Mode
    end
  end # module ProjectToPlane
end # module Crafty
