require 'sketchup.rb'
require 'crafty/util.rb'

module Crafty
  module HighlightIntersections
    # Initializes the highlighting tool
    def self.start_tool
      selected_solids = Sketchup.active_model.selection.find_all { |e| (e.is_a? Sketchup::Group) and e.manifold? }
      if selected_solids.length > 1
        UI.messagebox "Please select at least two solid groups to use this tool."
      else
        Sketchup.active_model.selection.clear
        Sketchup.active_model.selection.add *selected_solids

      end
    end

    # Returns a group that represents the complete intersection of all given solids.
    # @param solids [Enumerable<Sketchup::Group>] the solids to intersect. If any solid is not manifold, it will be
    #   ignored
    # @return [nil, Sketchup::Group] the resultant intersection, or `nil` if any of the solids don't overlap
    def self.find_total_intersection(solids)
      manifold_solids = self.find_all_manifold_solids solids
      if manifold_solids.empty?
        return nil
      else
        intersection = manifold_solids.first
        manifold_solids[1...manifold_solids.length].each do |solid|
          unless intersection.nil?
            # Slight perf improvement by intersecting bounding boxes before the solids themselves
            intersecting_bounds = intersection.bounds.intersect solid.bounds
            if intersecting_bounds.empty?
              return nil
            end
            intersection = intersection.intersect solid
            return nil if intersection.nil?
          end
        end
      end
      return intersection
    end

    # @param collection [Enumerable]
    # @return [Array<Sketchup::Group>] an array of all manifold solid groups within the given collection
    def self.find_all_manifold_solids(collection)
      if collection.nil?
        return []
      else
        return collection.find_all { |e| (e.is_a? Sketchup::Group) and e.manifold? }
      end
    end
  end # module HighlightIntersections
end # module Crafty
