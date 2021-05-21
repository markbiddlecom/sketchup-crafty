require 'sketchup.rb'
require 'crafty/util.rb'

module Crafty
  module HighlightIntersections
    class Choose < Crafty::ToolStateMachine::Mode
      # Creates a new mode class
      # @param primary_face [Sketchup::Face] the face we're going to plot intersections for
      def initialize(primary_face)
        @primary_face = primary_face
        @penetration_areas = HighlightIntersections.new_empty_faces_list
        @abutting_areas = HighlightIntersections.new_empty_faces_list
        @faces_mode = Crafty::Util::Cycle.new FACES_MODE_PENETRATING, FACES_MODE_ALL, FACES_MODE_ABUTTING
      end
    end # class DrawIntersectionsMode

    # @return [Array<Sketchup::Face>]
    def self.new_empty_faces_list
      return []
    end
  end # module HighlightIntersections

  STATUS_ADD_INTERSECTING_GROUP = "[Shift + Left-Click] on a solid group to intersect the source face with"
  STATUS_READY = "[Shift + Left-Click] add/remove intersecting solid; [Tab] cycle intersection highlights; [Left-Click]/[Shift + Tab]"

  FACES_MODE_PENETRATING = "penetrating"
  FACES_MODE_ABUTTING = "abutting"
  FACES_MODE_ALL = "all"
end # module Crafty
