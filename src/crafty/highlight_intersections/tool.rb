# frozen_string_literal: true

require 'crafty/highlight_intersections/highlight.rb'
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
                      !Util::Attributes.get_panel_faces(e).nil?
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

    # @param primary_solid [Sketchup::Group] a manifold solid containing the face for which to highlight intersections
    # @param face_type [Symbol] either `:primary_face` or `:back_face`
    # @param solids [Array<Sketchup::Group>] the list of manifold solids to intersect against `primary_solid`
    # @param xform_primary_to_world [Geom::Transformation] a world coordinate transformation for geometry from the
    #   primary solid
    # @param xform_solids_to_world [Array<Geom::Transformation>] a world coordinate transformation for each of the
    #   groups in `solids`
    # @return [Array<Highlight>] a list of `:penetrating` and `:abutting` faces
    def self.find_intersections(primary_solid, face_type, solids,
        xform_primary_to_world: IDENTITY, xform_solids_to_world: nil)
      test_face, penetrating_highlights, non_penetrating, xform_non_penetrating = find_penetrating_faces(
          primary_solid, face_type, solids,
          xform_primary_to_world: xform_primary_to_world, xform_solids_to_world: xform_solids_to_world
        )
      abutting_highlights = []
      unless non_penetrating.empty?
        abutting_highlights = find_abutting_faces(primary_solid, test_face, non_penetrating,
                                                  xform_primary_to_world: xform_primary_to_world,
                                                  xform_solids_to_world: xform_non_penetrating)
      end
      penetrating_highlights + abutting_highlights
    end

    # Determines the areas on the primary solid's primary face that intersect with any of the given solids
    # @param primary_solid [Sketchup::Group] a manifold solid containing the face for which to highlight intersections
    # @param face_type [Symbol] either `:primary_face` or `:back_face`
    # @param solids [Array<Sketchup::Group>] a collection of manifold solids to find intersections with
    # @param xform_primary_to_world [Geom::Transformation] a world coordinate transformation for geometry from the
    #   primary solid
    # @param xform_solids_to_world [Array<Geom::Transformation>] a world coordinate transformation for each of the
    #   groups in `solids`
    # @return [Sketchup::Face, Array(Array<Highlight>, Array<Sketchup::Group>, Array<Geom::Transformation>)] the face
    #   to test for highlights, an array of the penetrating faces from `solids`, the non-penetrating members of
    #   solids`, and their world coordinate transforms
    def self.find_penetrating_faces(primary_solid, face_type, solids,
        xform_primary_to_world: IDENTITY, xform_solids_to_world: nil)
      faces = Util::Attributes.get_panel_faces(primary_solid)
      test_face = faces&.fetch(face_type)

      raise "Group #{primary_solid.persistent_id} does not define panel faces" if test_face.nil?

      non_penetrating = []
      xform_non_penetrating = []

      penetrating_highlights = solids.flat_map.with_index { |solid, index|
        primary_copy = primary_solid.copy
        solid_copy = solid.copy
        intersection = primary_copy.intersect(solid_copy)

        abutting = []
        unless intersection.nil?
          abutting = find_abutting_faces(
              primary_solid,
              test_face,
              [intersection],
              type: :penetrating,
              source: solid,
              xform_primary_to_world: xform_primary_to_world,
              xform_solids_to_world: [intersection.transformation]
            )
        end

        non_penetrating << solid if abutting.empty?
        xform_non_penetrating << xform_solids_to_world&.at(index) if abutting.empty?

        primary_copy.erase! unless primary_copy.deleted?
        solid_copy.erase! unless solid_copy.deleted?
        intersection.erase! unless intersection.deleted?

        abutting
      }
      [test_face, penetrating_highlights, non_penetrating, xform_non_penetrating]
    end

    # Identifies the faces from the solids list that abut the given face
    # @param primary_solid [Sketchup::Group] a manifold solid containing the face for which to highlight intersections
    # @param primary_face [Sketchup::Face] the to test against each of the solids
    # @param solids [Enumerable<Sketchup::Group>] the solids containing the abutting faces
    # @param type [Symbol] either `:penetrating` or `:abutting`
    # @param xform_primary_to_world [Geom::Transformation] a world coordinate transformation for geometry from the
    #   primary solid
    # @param xform_solids_to_world [Array<Geom::Transformation>] a world coordinate transformation for each of the
    #   groups in `solids`
    # @param source [Sketchup::Group] the group to record as the source of highlights if it should not be `solids`
    # @return [Array<Highlight>]
    def self.find_abutting_faces(primary_solid, primary_face, solids,
        type: :abutting, xform_primary_to_world: IDENTITY, xform_solids_to_world: nil, source: nil)
      primary_plane = Util::Plane.new(primary_face.plane).transform!(xform_primary_to_world)
      solids.flat_map.with_index { |solid, index|
        solid_transform = xform_solids_to_world&.at(index) || IDENTITY
        solid.entities
             .grep(Sketchup::Face)
             .filter { |face| primary_plane == Util::Plane.new(face.plane).transform!(solid_transform) }
             .map { |face| Highlight.new(source || solid, primary_solid, face, type, face_transform: solid_transform) }
      }
    end
  end # module HighlightIntersections
end # module Crafty
