# frozen_string_literal: true

module Crafty
  module HighlightIntersections
    class Highlight
      attr_reader :source_pid
      attr_reader :target_pid
      attr_reader :type
      attr_reader :split_vector
      attr_reader :loops
      attr_reader :polygons

      # @param source [Sketchup::Group] the intersecting or abutting solid
      # @param target [Sketchup::Group] the solid that has been intersected or abutted
      # @param face [Sketchup::Face] the face describing the intersecting area
      # @param type [Symbol] the type of highlight this represents `:penetrating` or `:abutting`
      # @param face_transform [Geom::Transformation] a transformation to apply to the captured geometry
      def initialize(source, target, face, type, face_transform: IDENTITY)
        @source_pid = source.persistent_id
        @target_pid = target.persistent_id
        @type = type
        @split_vector = (Util::Attributes.get_panel_vector target)&.cross(face.normal)

        @loops = face.loops.map { |l| l.vertices.map { |v| face_transform * v.position } }

        mesh = face.mesh
        @polygons = mesh.polygons.flat_map { |indices|
          indices.map { |index| face_transform * mesh.point_at(index.abs) }
        }
      end
    end
  end # module HighlightIntersections
end # module Crafty
