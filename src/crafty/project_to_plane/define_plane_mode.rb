# frozen_string_literal: true

module Crafty
  module ProjectToPlane
    class DefinePlanePoint < ToolStateMachine::Mode
      # @return [Sketchup::InputPoint]
      attr_accessor :inference_ip, :selection_ip

      # @return [Geom::Vector3d]
      attr_accessor :vector

      # @return [Enumerable<Sketchup::Entity>]
      attr_accessor :selection

      # @return [Chords::Chordset] the chords available from this tool
      attr_reader :chordset

      # @abstract
      # @return [Geom::Point3d] the inference point to use when selecting
      def inference_point; end

      # @abstract
      # @return [ToolStateMachine::Mode] the mode to transition to after the point for this mode has been entered
      def next_mode; end

      # @abstract
      # @param tool [ToolStateMachine::Tool] the tool doing the drawing
      # @param view [Sketchup::View] the current view
      # @return [void]
      def custom_draw(tool, view); end

      # @abstract
      # @param bounds [Geom::BoundingBox] the bounds to extend
      # @return [void]
      def extend_bounds(bounds); end

      # Invoked each time this mode is activated. Sets up the input chords and the inference points.
      def activate_mode(tool, _old_mode, view)
        @chordset = Chords::Chordset.new(
            {
              cmd: :switch,
              help: 'Define Plane With Face',
              trigger: Chords::Chord::TAB,
              on_trigger: Util.method_ref(self, :on_switch),
            },
            {
              cmd: :select,
              help: 'Select Point',
              trigger: Chords::Chord::LBUTTON,
              on_trigger: Util.method_ref(self, :on_select),
            }
          )

        inference_pt = self.inference_point
        sc = view.screen_coords inference_pt
        @inference_ip = Sketchup::InputPoint.new inference_pt
        @inference_ip.pick view, sc.x, sc.y, nil
        @selection_ip = Sketchup::InputPoint.new inference_pt

        @vector = nil
        tool.bounds.clear.add(inference_pt)
        self.extend_bounds(tool.bounds)
        view.invalidate
      end

      # @param event [Chords::ClickEnactEvent] details about the event
      def on_select(_chord, event)
        if @vector.nil?
          UI.beep
        else
          event.new_mode = self.next_mode
        end
      end

      # @param event [Chords::EnactEvent] details about the event
      def on_switch(_chord, event)
        event.new_mode = SelectFace.new(@selection, self)
      end

      def vcb
        if @vector.nil?
          [false, 'Distance', '']
        else
          [true, 'Distance', @vector.length]
        end
      end

      def on_mouse_move(tool, _flags, x, y, view)
        if @selection_ip.pick view, x, y, @inference_ip
          tool.bounds.add @selection_ip.position
          self.extend_bounds tool.bounds
          @vector = @selection_ip.position.vector_to @inference_ip.position
        end
        view.invalidate
        self
      end

      def draw(tool, view)
        self.custom_draw tool, view
        @selection_ip.draw view
        true
      end
    end # class DefinePlanePoint

    class Pt1 < DefinePlanePoint
      # @param selection [Enumerable<Sketchup::Entity>] a list of entities containing edges to project
      # @param center_point [Geom::Point3d] the point that represents the center of the selection to project
      def initialize(selection, center_point)
        self.selection = selection
        @center_point = center_point
      end

      # @return [String]
      def status
        'Select the point defining the origin of the plane'
      end

      def inference_point
        @center_point
      end

      def next_mode
        Pt2.new self.selection, self.selection_ip.position
      end

      def custom_draw(_tool, view)
        view.line_stipple = '.'
        view.line_width = 1
        view.set_color_from_line(@center_point, self.selection_ip.position)
        view.draw_line(@center_point, self.selection_ip.position)
        view.draw_points(@center_point, 12, 2, 'blue')
      end
    end # class Pt1

    class Pt2 < DefinePlanePoint
      # @param selection [Enumerable<Sketchup::Entity>] a list of entities containing edges to project
      # @param plane_origin [Geom::Point3d] the selected origin point of the plane
      def initialize(selection, plane_origin)
        self.selection = selection
        @origin_point = plane_origin
      end

      # @return [String]
      def status
        'Select a second point lying on the plane'
      end

      def inference_point
        @origin_point
      end

      def next_mode
        Pt3.new self.selection, @origin_point, self.selection_ip.position
      end

      def extend_bounds(bounds)
        bounds.add @origin_point
      end

      def custom_draw(_tool, view)
        view.line_stipple = ''
        view.line_width = 3
        view.set_color_from_line(@origin_point, self.selection_ip.position)
        view.draw_line(@origin_point, self.selection_ip.position)
        view.draw_points(@origin_point, 12, 5, 'black')
      end
    end # class Pt2

    class Pt3 < DefinePlanePoint
      # @param selection [Enumerable<Sketchup::Entity>] a list of entities containing edges to project
      # @param plane_origin [Geom::Point3d] the selected origin point of the plane
      # @param pt2 [Geom::Point3d] the selected second point of the plane
      def initialize(selection, plane_origin, pt2)
        self.selection = selection
        @origin_point = plane_origin
        @pt2 = pt2
      end

      # @return [String]
      def status
        'Select the final, non-colinear point'
      end

      def inference_point
        @pt2
      end

      def next_mode
        u = @pt2.vector_to self.selection_ip.position
        v = @pt2.vector_to @origin_point
        normal = u.cross v

        ProjectToPlane.project_edges_to_plane(
            self.selection,
            Util::Plane.new([normal.x, normal.y, normal.z, ORIGIN.distance(@origin_point)])
          )
        ToolStateMachine::Mode::END_OF_OPERATION
      end

      def extend_bounds(bounds)
        bounds.add @origin_point, @pt2
      end

      def custom_draw(_tool, view)
        view.line_stipple = ''
        view.line_width = 3
        view.set_color_from_line(@origin_point, @pt2)
        view.draw_line(@origin_point, @pt2)
        view.set_color_from_line(@pt2, self.selection_ip.position)
        view.draw_line(@pt2, self.selection_ip.position)
        view.line_width = 1
        view.draw_points(@origin_point, 12, 5, 'black')
        view.draw_points(@pt2, 12, 1, 'black')
      end
    end # class Pt3
  end # module ProjectToPlane
end # module Crafty
