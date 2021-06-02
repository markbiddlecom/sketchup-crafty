# frozen_string_literal: true

module Crafty
  module HighlightIntersections
    COLOR_PENETRATING = 'red'
    COLOR_ABUTTING = 'green'

    COLOR_PRIMARY = 'black'
    COLOR_SECONDARY = 'gray'

    class PrimaryMode < Crafty::ToolStateMachine::Mode
      # @param panel_solids [Array<Sketchup::Group>] the set of groups that can be cross-intersected
      def initialize(panel_solids, initial_selected_index)
        @initial_selected_index = initial_selected_index
        @panel_solids = panel_solids
      end

      def activate_mode(tool, _old_mode, view)
        self.select_primary(@initial_selected_index || 0)
        @highlight_mode = Util::Cycle.new(:all, :penetrating, :abutting)
        puts @highlight_mode
        tool.bounds.clear.add(*@panel_solids.map(&:bounds))
        @penetrating_texture = Plugin.load_texture_asset(view, 'penetrating.png')
        @abutting_texture = Plugin.load_texture_asset(view, 'abutting.png')
        view.invalidate
      end

      def deactivate_mode(_tool, _new_mode, view)
        view.release_texture @penetrating_texture[:id]
        view.release_texture @abutting_texture[:id]
      end

      def draw(_tool, view)
        # Highlight all the secondary solids
        @secondary_solids.each { |solid| Util.highlight_bounds(solid.bounds, view, color: COLOR_SECONDARY) }

        # Highlight the primary face
        Util.highlight_face(
            @primary_face, view, color: 'orange', width: 3, transform: @primary_solid.transformation, overlaid: true
          )

        # Faces
        [
          [@penetrating, :penetrating, COLOR_PENETRATING, @penetrating_texture],
          [@abutting, :abutting, COLOR_ABUTTING, @abutting_texture],
        ].flat_map { |(highlights, mode, color, texture)|
          @highlight_mode == :all || @highlight_mode == mode ? highlights.map { |h| [h, color, texture] } : []
        }.each { |(highlight, color, texture)|
          self.draw_highlight(view, highlight, color, texture)
        }
      end

      private

      def draw_highlight(view, highlight, color, texture)
        Util.draw(view, GL_TRIANGLES, *highlight.polygons, color: color, overlaid: true, texture: texture)
        Util.draw(view, GL_LINE_LOOP, *highlight.loops.first, color: color, width: 3, overlaid: true)
      end

      # @param new_primary [Integer] the index of the new primary solid
      def select_primary(new_primary)
        # @type [Sketchup::Group]
        @primary_solid = @panel_solids[new_primary]
        @primary_face = Util::Attributes.find_primary_faces(@primary_solid.entities).first
        @secondary_solids = @panel_solids.reject.with_index { |_, i| i == new_primary }
        @penetrating = HighlightIntersections.find_penetrating_faces(
            @primary_solid, @secondary_solids, transform: @primary_solid.transformation
          )
        # @abutting = HighlightIntersections.find_abutting_faces(
        #     @primary_solid, @primary_face, @secondary_solids, transform: @primary_solid.transformation
        #   )
        @abutting = []
      end
    end # class PrimaryMode
  end # module HighlightIntersections
end # module Crafty
