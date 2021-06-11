# frozen_string_literal: true

module Crafty
  module HighlightIntersections
    COLOR_PENETRATING = 'red'
    COLOR_ABUTTING = 'green'

    COLOR_PRIMARY = 'orange'
    COLOR_BACK = 'yellow'
    COLOR_SECONDARY = 'gray'

    FACE_COLORS = { primary_face: COLOR_PRIMARY, back_face: COLOR_BACK }.freeze
    HIGHLIGHT_COLORS = { penetrating: COLOR_PRIMARY, abutting: COLOR_ABUTTING }.freeze

    class PrimaryMode < ToolStateMachine::Mode
      # @param panel_solids [Array<Sketchup::Group>] the set of groups that can be cross-intersected
      def initialize(panel_solids, initial_selected_index)
        @initial_selected_index = initial_selected_index
        @panel_solids = panel_solids
      end

      def activate_mode(tool, _old_mode, view)
        @secondary_hover = nil
        @highlight_hover = nil

        @highlight_mode = Util::Cycle.new(:all, :penetrating, :abutting)
        @face_mode = Util::Cycle.new(:primary_face, :back_face)
        @area_mode = Util::Cycle.new(:full, :near, :far, :middle)
        @mod_mode = Util::Cycle.new(:carve, :draw, :guide)

        self.select_primary(@initial_selected_index || 0)

        tool.bounds.clear.add(*@panel_solids.map(&:bounds))
        view.invalidate

        @textures = {
          penetrating: Plugin.load_texture_asset(view, 'penetrating.png'),
          abutting: Plugin.load_texture_asset(view, 'abutting.png'),
        }.freeze

        @chordset = Chords::Chordset.new(
            {
              cmd: :select,
              help: 'Select primary or toggle face',
              trigger: Chords::Chord::LBUTTON,
              on_trigger: Util.method_ref(self, :on_select),
            },
            {
              cmd: :highlight_mode,
              help: 'Change Highlight Mode',
              trigger: [Chords::Chord::TAB],
              on_trigger: Util.method_ref(self, :on_change_highlight_mode),
            }
          )
      end

      def deactivate_mode(_tool, _new_mode, view)
        view.release_texture @penetrating_texture[:id]
        view.release_texture @abutting_texture[:id]
      end

      # @param chord [Chords::Chord]
      # @param event [Chords::ClickEnactEvent]
      def on_select(_chord, event)
        if !@highlight_hover.nil?
          @highlight_hover.selected = !@highlight_hover.selected
          event.view.invalidate
        elsif !@secondary_hover.nil?
          self.select_primary(@secondary_solids.find_index(@secondary_hover))
          event.new_mode = self.on_mouse_move(event.tool, 0, event.point.x, event.point.y, event.view)
        else
          # Nothing to click 😡
          UI.beep
          event.view.tooltip = 'Please select a new primary solid or a face to toggle'
        end
      end

      def on_change_highlight_mode(_chord, event)
        @face_mode.advance!
        event.view.invalidate
      end

      def on_mouse_move(_tool, _flags, x, y, view)
        # Figure out what the hovered element is. Short-circuit if the current highlight still contains the mouse point
        if @highlight_hover.nil? || !@highlight_hover.contains?(x, y, view)
          @highlight_hover = self.visible_highlights.filter { |h| h.contains?(x, y, view) }.last
          # Fall back to looking for a new primary?
          if @highlight_hover.nil?
            picked = view.pick_helper(x, y).best_picked
            if picked != @secondary_hover && @secondary_solids.include?(picked)
              # Changed from a different secondary hover
              @secondary_hover = picked
              view.invalidate
            elsif !@secondary_hover.nil?
              # Went from a secondary hover to nil
              @secondary_hover = nil
              view.invalidate
            end
          else
            # Went from either a secondary hover or nil to a highlight hover
            @secondary_hover = nil
            view.invalidate
          end
        end
        # No mode change needed
        self
      end

      def draw(_tool, view)
        self.draw_secondaries(view)
        self.draw_primary(view)
        self.draw_highlights(view)
      end

      private

      attr_reader :primary_face, :back_face

      # @return [Enumerable<Highlight>] an enumerator for the highlights that are currently visible
      def visible_highlights
        @highlights.filter { |h| self.visible?(h) }
      end

      # @param highlight [Highlight] the highlight to test
      # @return [Boolean] `true` if `highlight` should be rendered and `false` otherwise
      def visible?(highlight)
        @highlight_mode == :all || @highlight_mode.cur_mode == highlight.type
      end

      # @param view [Sketchup::View]
      def draw_secondaries(view)
        @secondary_solids.each { |solid|
          if solid == @secondary_hover
            face = Util::Attributes.get_panel_faces(solid)&.fetch(@face_mode.cur_mode)
            unless face.nil?
              Util.highlight_face(
                  face,
                  view,
                  color: @face_mode.map(COLOR_PRIMARY, COLOR_BACK),
                  width: 3,
                  transform: solid.transformation,
                  overlaid: true
                )
            end
          else
            Util.highlight_bounds(solid.bounds, view, color: COLOR_SECONDARY)
          end
        }
      end

      # @param view [Sketchup::View]
      def draw_primary(view)
        Util.highlight_face(
            self.send(@face_mode.cur_mode),
            view,
            color: @face_mode.map(COLOR_PRIMARY, COLOR_BACK),
            width: 3,
            transform: @primary_solid.transformation,
            overlaid: true
          )
      end

      # @param view [Sketchup::View]
      def draw_highlights(view)
        self.visible_highlights.each { |highlight|
          self.draw_highlight(view, highlight, HIGHLIGHT_COLORS[highlight.type], @textures[highlight.type][:id])
        }
      end

      # @param view [Sketchup::View]
      # @param highlight [Highlight]
      # @param color [String]
      # @param texture [String]
      def draw_highlight(view, highlight, color, texture)
        if highlight.selected
          Util.draw(view, GL_TRIANGLES, *highlight.polygons, color: color, overlaid: true, texture: texture)
        end
        Util.draw(
            view,
            GL_LINE_LOOP,
            *highlight.loops.first,
            color: color,
            width: highlight.selected ? 3 : 1,
            overlaid: true
          )
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
