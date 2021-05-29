# frozen_string_literal: true

require 'crafty/project_to_plane/define_plane_mode.rb'
require 'crafty/project_to_plane/select_face_mode.rb'

module Crafty
  module ProjectToPlane
    # Initializes the projection tool
    def self.start_tool
      edges = Sketchup.active_model.selection.grep(Sketchup::Edge)
      faces = Sketchup.active_model.selection.grep(Sketchup::Face)
      if edges.empty? && faces.empty?
        UI.beep
        Sketchup.active_model.active_view.tooltip = 'Please select at least one edge first'
      else
        if edges.empty? && !faces.empty?
          edges = faces.flat_map(&:edges)
          Sketchup.active_model.selection.add(edges)
        end

        Sketchup.active_model.select_tool(ToolStateMachine::Tool.new {
          Pt1.new edges, Geom::BoundingBox.new.add(edges.map(&:bounds)).center
        })
      end
    end

    # Projects all of the edges in the given list to
    # @param edges [Enumerable<Sketchup::Entity>, Sketchup::Entities] a list containing the edges to project
    # @param plane [Crafty::Util::Plane]
    def self.project_edges_to_plane(edges, plane)
      projection_group = Sketchup.active_model.active_entities.add_group
      projection_group.name = 'Projection'

      edges.grep(Sketchup::Edge) { |edge|
        vertices = [edge.start.position, edge.end.position].map { |pt| plane.project_2d(pt) }
        projection_group.entities.add_edges(vertices.map { |pt| Geom::Point3d.new(pt.x, 0, pt.y) })
      }

      projection_group.transform! XZ_PLANE.transformation_to(plane)
      projection_group
    end
  end # module ProjectToPlane
end # module Crafty
