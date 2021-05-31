# frozen_string_literal: true

module Crafty
  TOLERANCE = 0.001.inch

  ZERO_VECTOR = Geom::Vector3d.new 0, 0, 0
  ORIGIN = Geom::Point3d.new 0, 0, 0
  UP_VECTOR = Geom::Vector3d.new 0, 0, 1

  IDENTITY = Geom::Transformation.new

  ZERO_LENGTH = 0.to_l
  UNIT_LENGTH = 1.to_l
end # module Crafty
