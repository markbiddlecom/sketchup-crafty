# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/plane.rb'

module Crafty
  TOLERANCE = 0.001.inch

  ZERO_VECTOR = Geom::Vector3d.new 0, 0, 0
  ORIGIN = Geom::Point3d.new 0, 0, 0
  UP_VECTOR = Geom::Vector3d.new 0, 0, 1

  IDENTITY = Geom::Transformation.new

  XZ_PLANE = Plane.new([0, 1, 0, 0])
end # module Crafty
