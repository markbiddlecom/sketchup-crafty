# frozen_string_literal: true

require 'crafty/highlight_intersections/choose.rb'

module Crafty
  module HighlightIntersections
    # Initializes the highlighting tool
    def self.start_tool
      selected_solids = Sketchup.active_model.selection.find_all { |e| (e.is_a? Sketchup::Group) and e.manifold? }
      if selected_solids.length > 1
        UI.messagebox 'Please select at least two solid groups to use this tool.'
      else
        Sketchup.active_model.selection.clear
        Sketchup.active_model.selection.add(*selected_solids)
      end
    end

    # Returns a group that represents the intersection of the first solid in the given list with the union of the
    # remaining solids.
    # @param solids [Enumerable<Sketchup::Group>] the solids to intersect. If any solid is not manifold, it will be
    #   ignored
    # @return [nil, Sketchup::Group] the resultant intersection, or `nil` if any of the solids don't overlap
    def self.find_total_intersection(solids)
      manifold_solids = self.find_all_manifold_solids solids
      if manifold_solids.length < 2
        nil
      else
        primary = manifold_solids.first
        union = manifold_solids[1...manifold_solids.length].reduce do |current_union, solid|
          current_union.union solid
        end
        primary.intersect union
      end
    end

    # @param collection [Enumerable]
    # @return [Array<Sketchup::Group>] an array of all manifold solid groups within the given collection
    def self.find_all_manifold_solids(collection)
      if collection.nil?
        []
      else
        collection.find_all { |e| (e.is_a? Sketchup::Group) and e.manifold? }
      end
    end

    module EventHandlers
      CHORDSET = Crafty::Chords::Chordset.new(
          {
            cmd: :select_primary,
            help: 'change primary solid',
            trigger: Crafty::Chords::Chord::LBUTTON,
            on_trigger: Crafty::Chords::Chord.event_handler { |_, e| on_select_primary(e.x, e.y) },
          },
          {
            cmd: :change_secondary,
            help: 'toggle an intersecting group',
            modifiers: Crafty::Chords::Chord::CTRL_CMD,
            trigger: Crafty::Chords::Chord::LBUTTON,
            on_trigger: Crafty::Chords::Chord.event_handler { |_, e| on_select_secondary(e) },
          }
        )

      # @param x [Numeric] the x-coordinate of the click
      # @param y [Numeric] the y-coordinate of the click
      def self.on_select_primary(x, y); end

      # @param event [Crafty::Chords::ClickEnactEvent, Crafty::Chords::DragEnactEvent] an event describing the cause of
      #   the event
      def self.on_select_secondary(event); end
    end # module EventHandlers

    class NoPrimary < Crafty::ToolStateMachine::Mode
      def initialize
        EventHandlers::CHORDSET.enable! :cmd
      end
    end # class ToolMode
  end # module HighlightIntersections
end # module Crafty
