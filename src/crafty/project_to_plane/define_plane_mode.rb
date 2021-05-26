# frozen_string_literal: true

require 'crafty/chord.rb'
require 'crafty/consts.rb'
require 'crafty/util.rb'

module Crafty
  module ProjectToPlane
    class DefinePlanePt1 < ToolStateMachine::Mode
      # @param center_point [Geom::Point3d] the point that represents the center of the selection to project
      def initialize(center_point)
        @center_point = center_point
      end

      def activate_mode(_tool, _old_mode, _view)
        Sketchup.vcb_label = 'Distance'
        @anchor_pt = Sketchup::InputPoint.new @center_point
        @input_pt = Sketchup::InputPoint.new @anchor_pt
        @chordset = Chordset.new(
            { cmd: :switch, help: 'Select face', trigger: Chord::TAB, on_trigger: Util.method_ref(self) }
          )
      end

      def enable_vcb?
        cur_pt = @input_pt&.position || @center_point
        cur_pt.distance(@center_point) > TOLERANCE
      end

      # @param
      def on_trigger(_chord, event); end
    end

    class DefinePlanePt2 < ToolStateMachine::Mode
    end

    class DefinePlanePt3 < ToolStateMachine::Mode
    end
  end # module ProjectToPlane
end # module Crafty
