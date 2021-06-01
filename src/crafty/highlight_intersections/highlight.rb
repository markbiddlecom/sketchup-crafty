# frozen_string_literal: true

module Crafty
  module HighlightIntersections
    class Highlight
      # param face [Sketchup::Face] the face to highlight
      # param type [Symbol] the type of highlight this represents `:penetrating` or `:abutting`
      def initialize(face, type)
        instance_path = Util.path_to(face)
        @path = instance_path.persistent_id_path
        @type = type
      end
    end
  end # module HighlightIntersections
end # module Crafty
