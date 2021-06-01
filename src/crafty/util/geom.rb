# frozen_string_literal: true

require 'sketchup.rb'

module Crafty
  module Util
    # Constructs a bounding box from two coordinates
    # @return [Geom::Bounds2d] the bounding box
    # @overload bounds_from_pts(start, end)
    #   @param start [Geom::Point2d] the coordinates of the bound's first corner
    #   @param end [Geom::Point2d] the coordinates of the bound's opposing corner
    # @overload bounds_from_pts(start, x_end, y_end)
    #   @param start [Geom::Point2d] the coordinates of the bound's first corner
    #   @param x_end [Numeric] the x-coordinate of the bound's opposing corner
    #   @param y_end [Numeric] the y-coordinate of the bound's opposing corner
    # @overload bounds_from_pts(x_start, y_start, end)
    #   @param x_start [Numeric] the x-coordinate of the bound's first corner
    #   @param y_start [Numeric] the y-coordinate of the bound's opposing corner
    #   @param end [Geom::Point2d] the coordinates of the bound's opposing corner
    # @overload bounds_from_pts(x_start, y_start, x_end, y_end)
    #   @param x_start [Numeric] the x-coordinate of the bound's first corner
    #   @param y_start [Numeric] the y-coordinate of the bound's opposing corner
    #   @param x_end [Numeric] the x-coordinate of the bound's opposing corner
    #   @param y_end [Numeric] the y-coordinate of the bound's opposing corner
    def self.bounds_from_pts(*args)
      x_start = 0
      y_start = 0
      x_end = 0
      y_end = 0
      if args.size == 2
        pt1, pt2 = args
        x_start, y_start = pt1.to_a
        x_end, y_end = pt2.to_a
      elsif args.size == 3 && args[0].is_a?(Geom::Point2d)
        pt1, x_end, y_end = args
        x_start, y_start = pt1.to_a
      elsif args.size == 3 && args[2].is_a?(Geom::Point2d)
        x_start, y_start, pt2 = args
        x_end, y_end = pt2.to_a
      elsif args.size == 4
        x_start, y_start, x_end, y_end = args
      end
      Geom::Bounds2d.new(
          [x_start, x_end].min, [y_start, y_end].min,
          (x_end - x_start).abs, (y_end - y_start).abs
        )
    end
  end # module Util
end # module Crafty
