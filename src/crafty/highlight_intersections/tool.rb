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
    # @param solids [Array<Sketchup::Group>] a collection of manifold solids to find intersections with
    # @param transform [Geom::Transformation] an optional transformation to apply to the identified faces before
    #   returning them (e.g., to translate them to world-space coordinates)
    # @return [Array<Highlight>] an array of meshes that represent the intersecting areas of `primary_solid`
    def self.find_penetrating_faces(primary_solid, solids, transform: IDENTITY)
      primary_face = Util::Attributes.find_primary_faces(primary_solid.entities)[0]
      raise(StandardError, 'primary_solid does not contain a face marked "primary"') if primary_face.nil?

      solids.flat_map { |solid|
        primary_copy = primary_solid.copy
        solid_copy = solid.copy
        intersection = primary_copy.intersect(solid_copy)

        abutting = []
        unless intersection.nil?
          abutting = find_abutting_faces(
              primary_solid, primary_face, [intersection],
              type: :penetrating, transform: intersection.transformation, override_source: solid
            )
        end

        primary_copy.erase! unless primary_copy.deleted?
        solid_copy.erase! unless solid_copy.deleted?
        intersection.erase! unless intersection.deleted?

        abutting
      }
    end

    # Identifies the faces from the solids list that abut the given face
    # @param primary_face [Sketchup::Face] the to test against each of the solids
    # @param solids [Enumerable<Sketchup::Group>] the solids containing the abutting faces
    # @param type [Symbol] either `:penetrating` or `:abutting`
    # @param transform [Geom::Transformation] an optional transformation to apply to the identified faces before
    #   returning them (e.g., to translate them to world-space coordinates)
    # @return [Array<Highlight>]
    def self.find_abutting_faces(target, primary_face, solids,
        type: :abutting, transform: IDENTITY, override_source: nil)
      primary_plane = Util::Plane.new(primary_face.plane)
      solids.flat_map { |solid|
        solid.entities
             .grep(Sketchup::Face)
             .filter { |face| primary_plane == Util::Plane.new(face.plane) }
             .map { |face| Highlight.new(override_source || solid, target, face, type, transform: transform) }
      }
    end
  end # module HighlightIntersections
end # module Crafty
