# frozen_string_literal: true

module Crafty
  module Util
    # Copies the edges and faces for the given face element to the given entity list.
    # @note this does _not_ copy textures, attributes, or other information from the source face.
    # @param face [Sketchup::Face] the face to clone
    # @param entities [Sketchup::Entities] the entities list to clone the face into
    # @param offset [Geom::Vector3d] an optional offset for all the face's vertices
    # @return [Array<Sketchup::Face>] the cloned face(s) within `entities`; will generally be a single face
    def self.clone_face_geometry(face, entities, offset = ZERO_VECTOR)
      # Create a temporary group
      temp_group = entities.add_group
      temp_entities = temp_group.entities

      # Use the face's mesh to add a bunch of connected polygons (triangles) to the temporary group
      mesh = face.mesh

      # The tessellated triangles in a face's mesh can be smaller than SketchUp's tolerance threshold for modeling.
      # To handle this case, we'll apply a scale factor while we process and reverse that when we ungroup at the end.
      results = mesh_to_polygons_and_scale_factor mesh, TOLERANCE * 1.1, Plane.new(face.plane)
      polygons = results[0]
      scale_factor = results[1]
      results = operation_transforms(mesh.points[0], scale_factor)
      transform = results[0]
      inverse_transform = results[1]

      polygons.each do |polygon|
        temp_entities.add_face(*(polygon.map { |pt| transform * pt }))
      end

      # Now we've got a whole bunch of interior edges for the polygons that don't belong on the new face. So we'll
      # delete all the excess edges and call the remaining face(s) the result. There should generally only be one face
      # left over, but it depends on lots of things going right ;)
      temp_entities.erase_entities(
          temp_entities.grep(Sketchup::Edge).reject { |edge| edge.faces.size == 1 }
        )

      # Restore the original scale of the group points and explode it to drop all the faces into the desired entity list
      temp_group.transform! inverse_transform unless inverse_transform.identity?
      temp_group.transform! Geom::Transformation.translation(offset) unless offset.length == 0.to_l
      result = temp_group.explode
      result == false ? [] : result.grep(Sketchup::Face)
    end
  end # module Util
end # module Crafty
