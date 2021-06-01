# frozen_string_literal: true

require 'crafty/highlight_intersections/primary_mode.rb'

module Crafty
  module HighlightIntersections
    # Initializes the highlighting tool
    def self.start_tool
      selected_solids =
          Sketchup.active_model
                  .selection
                  .find_all { |e|
                    e.is_a?(Sketchup::Group) &&
                      e.manifold? &&
                      Util::Attributes.find_primary_faces(e.entities).length == 1
                  }
      selected_index = selected_solids.find_index(Sketchup.active_model.selection.first)
      if selected_solids.length < 2
        UI.beep
        Sketchup.active_model.active_view.tooltip = 'Please select at least two panel solids'
      else
        Sketchup.active_model.selection.clear
        Sketchup.active_model.select_tool(ToolStateMachine::Tool.new {
          PrimaryMode.new(selected_solids, selected_index)
        })
      end
    end

    # Determines the areas on the primary solid's primary face that intersect with any of the given solids
    # @param primary_solid [Sketchup::Group] a manifold solid containing exactly one face marked as primary
    # @param solids [Array<Sketchup::Group>]
    # @return [Array<Geom::PolygonMesh>] an array of meshes that represent the intersecting areas of `primary_solid`
    def self.find_penetrating_faces(primary_solid, solids)
      primary_face = Util::Attributes.find_primary_faces(primary_solid.entities)[0]
      raise(StandardError, 'primary_solid does not contain a face marked "primary"') if primary_face.nil?

      solids.flat_map { |solid|
        primary_copy = primary_solid.copy
        solid_copy = solid.copy
        intersection = primary_copy.intersect(solid_copy)

        abutting = []
        if intersection.nil?
          abutting = find_abutting_faces(primary_face, intersection)
        else
          primary_copy.erase! unless primary_copy.deleted?
          solid_copy.erase! unless solid_copy.deleted?
          intersection.erase! unless intersection.deleted?
        end

        abutting
      }
    end

    # Identifies the faces from the solids list that abut the given face
    # @param primary_face [Sketchup::Face] the to test against each of the solids
    # @param solids [Enumerable<Sketchup::Group>] the solids containing the abutting faces
    # @return [Array<Geom::PolygonMesh>]
    def self.find_abutting_faces(primary_face, solids)
      primary_plane = Util::Plane.new(primary_face.plane)
      solids.flat_map { |solid|
        solid.entities
             .grep(Sketchup::Face)
             .filter { |face| primary_plane == Util::Plane.new(face.plane) }
             .map(&:mesh)
      }
    end
  end # module HighlightIntersections
end # module Crafty
