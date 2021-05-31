# frozen_string_literal: true

module Crafty
  module ToolStateMachine
    class Tool
      # @return [Proc] a block that returns the initial [Mode] for the tool.
      attr_accessor :activator

      # @return [Geom::BoundingBox] the bounding box containing the points of interest to the tool
      attr_accessor :bounds

      # @return [Array]
      attr_accessor :vcb_mode

      # @return [Geom::Bounds2d]
      attr_accessor :drag_rect

      # @yield [] a block that is called whenever the tool is activated
      # @yieldreturn [Mode] the initial state for the tool
      def initialize(&activator)
        @activator = activator
        @bounds = Geom::BoundingBox.new
        @vcb_mode = Mode::NULL_VCB_STATE
        @status_text = ''
        @drag_rect = nil
      end

      # @param mode [Mode]
      # @param view [Sketchup::View]
      # @param force_ui_update [Boolean]
      def apply_mode(mode, view = Sketchup.active_model.active_view, force_ui_update: false)
        if !mode.nil? && mode != @mode
          @mode.deactivate_mode self, mode, view unless @mode.nil?
          mode.activate_mode self, @mode, view
          @mode = mode
          self.apply_mode @mode.on_resume(self, view), view, force_ui_update: force_ui_update

          if mode == Mode::END_OF_OPERATION
            Sketchup.status_text = nil
            Sketchup.vcb_label = nil
            Sketchup.vcb_value = nil
            Sketchup.active_model.select_tool nil
            return
          end
        end
        self.update_ui force_ui_update
      end

      def update_ui(force = false)
        new_vcb = @mode.vcb
        if force || new_vcb != self.vcb_mode
          self.vcb_mode = new_vcb
          Sketchup.vcb_label = new_vcb[1]
          Sketchup.vcb_value = new_vcb[2]
        end
        new_status = [@mode.status, @mode.chordset.status].reject(&:nil?).reject(&:empty?).join('    |||    ')
        if force || new_status != @status_text
          @status_text = new_status
          Sketchup.status_text = new_status
        end
      end

      def drag_rect_to_pts3d
        r = self.drag_rect
        x_min = r.upper_left.x
        y_min = r.upper_left.y
        x_max = r.lower_right.x
        y_max = r.lower_right.y
        [
          Geom::Point3d.new(x_min, y_min),
          Geom::Point3d.new(x_max, y_min),
          Geom::Point3d.new(x_max, y_max),
          Geom::Point3d.new(x_min, y_max),
        ]
      end
    end # class Tool
  end # module ToolStateMachine
end # module Crafty
