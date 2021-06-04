# frozen_string_literal: true

module Crafty
  module HighlightIntersections
    COLOR_PENETRATING = 'red'
    COLOR_ABUTTING = 'green'

    COLOR_PRIMARY = 'orange'
    COLOR_BACK = 'yellow'
    COLOR_SECONDARY = 'gray'

    class PrimaryMode < Crafty::ToolStateMachine::Mode
      # @param panel_solids [Array<Sketchup::Group>] the set of groups that can be cross-intersected
      def initialize(panel_solids, initial_selected_index)
        @initial_selected_index = initial_selected_index
        @panel_solids = panel_solids
      end

      def activate_mode(tool, _old_mode, view)
        @highlight_mode = Util::Cycle.new(:all, :penetrating, :abutting)
        @face_mode = Util::Cycle.new(:primary_face, :back_face)
        @area_mode = Util::Cycle.new(:full, :near, :far, :middle)
        @mod_mode = Util::Cycle.new(:carve, :draw, :guide)

        self.select_primary(@initial_selected_index || 0)

        tool.bounds.clear.add(*@panel_solids.map(&:bounds))
        view.invalidate

        @penetrating_texture = Plugin.load_texture_asset(view, 'penetrating.png')
        @abutting_texture = Plugin.load_texture_asset(view, 'abutting.png')
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
            self.send(@face_mode.cur_mode),
            view,
            color: @face_mode.map(COLOR_PRIMARY, COLOR_BACK),
            width: 3,
            transform: @primary_solid.transformation,
            overlaid: true
          )

        # Faces
        [
          [:penetrating, COLOR_PENETRATING, @penetrating_texture],
          [:abutting, COLOR_ABUTTING, @abutting_texture],
        ].flat_map { |(mode, color, texture)|
          if @highlight_mode == :all || @highlight_mode == mode
            @highlights.filter { |h| h.type == mode }.map { |h| [h, color, texture] }
          else
            []
          end
        }.each { |(highlight, color, texture)|
          self.draw_highlight(view, highlight, color, texture)
        }
      end

      private

      attr_reader :primary_face, :back_face

      def draw_highlight(view, highlight, color, texture)
        Util.draw(view, GL_TRIANGLES, *highlight.polygons, color: color, overlaid: true, texture: texture)
        Util.draw(view, GL_LINE_LOOP, *highlight.loops.first, color: color, width: 3, overlaid: true)
      end

      # @param new_primary [Integer] the index of the new primary solid
      def select_primary(new_primary)
        # @type [Sketchup::Group]
        @primary_solid = @panel_solids[new_primary]
        @primary_face, @back_face = Util::Attributes.get_panel_faces(@primary_solid)
                                                    &.fetch_values(:primary_face, :back_face)
        @secondary_solids = @panel_solids.reject.with_index { |_, i| i == new_primary }
        @highlights = HighlightIntersections.find_intersections(
            @primary_solid, @face_mode.cur_mode, @secondary_solids,
            xform_primary_to_world: @primary_solid.transformation,
            xform_solids_to_world: @secondary_solids.map(&:transformation)
          )
      end
    end # class PrimaryMode
  end # module HighlightIntersections
end # module Crafty
