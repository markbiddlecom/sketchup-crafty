# frozen_string_literal: true

module Crafty
  module Chords
    class ChordsetState
      # @param chordset [Chordset] the chordset whose reachable chords should be returned
      # @return [Array<Chord>] the set of chords that are currently reachable with further input
      def reachable_chords(chordset)
        chordset.chords
      end

      # @param cur_modifiers [Integer] the current state of modifier keys
      # @param chordset [Chordset] the chordset processing the event
      # @return [ChordsetState] the new state after processing the modifier change
      def accept_modifier_change(_cur_modifiers, _chordset)
        self
      end

      # @param button [Integer] the button that was clicked
      # @param point [Geom::Point2d] the point where the mouse was clicked
      # @param cur_modifiers [Integer] the current state of modifier keys
      # @param chordset [Chordset] the chordset processing the event
      # @return [Array(ChordsetState, ToolStateMachine::Mode)] the new states for the chord and accompanying tool after
      #   processing the click
      def accept_click(_button, _point, _cur_modifiers, _chordset)
        [self]
      end

      # @param key [String] the key that was depressed
      # @param cur_modifiers [Integer] the current state of modifier keys
      # @param chordset [Chordset] the chordset processing the event
      # @return [ChordsetState] the new state after processing the key press
      def accept_keydown(_key, _cur_modifiers, _chordset)
        self
      end

      # @param key [String] the key that was released
      # @param cur_modifiers [Integer] the current state of modifier keys
      # @param chordset [Chordset] the chordset processing the event
      # @return [Array(ChordsetState, ToolStateMachine::Mode)] the new states for the chord and accompanying tool after
      #   processing the keypress.
      def accept_keyup(_key, _cur_modifiers, _chordset)
        [self]
      end

      # @param available_chords [Array<Chord>] the chords that are reachable before filtering
      # @param cur_modifiers [Integer] the current state of the modifier keys
      # @param downkeys [Array<String>] the currently depressed keys (other than the modifier keys)
      # @param sequence_index [Integer] the current sequence index a multi-step chord
      # @return [ChordsetState] the activated state given the current set of reachable chords
      def self.key_state_from_downkeys(available_chords, cur_modifiers, downkeys, sequence_index)
        reachable_chords = available_chords.find_all do |chord|
          if chord.enabled && (chord.modifiers == cur_modifiers) && (chord.button == 0)
            # This chord is still reachable if it has a key sequence with the given index and if the current set of
            # downkeys doesn't contain any keys not expected by the chord
            if chord.keys.length > sequence_index
              sequence_keys = chord.keys[sequence_index].to_set
              break downkeys.all? { |key| sequence_keys.include? key }
            end
          end
          false
        end
        if reachable_chords.length
          KeychordDown.new downkeys, reachable_chords, sequence_index
        else
          DeadEnd.new downkeys
        end
      end

      class Idle < ChordsetState
        def accept_click(button, point, cur_modifiers, chordset)
          event = ClickEnactEvent.new(point)
          chordset.chords.each do |chord|
            chord.enact(event) if chord.enabled && chord.modifiers == cur_modifiers && chord.button == button
          end
          [self, event.new_mode]
        end

        def accept_keydown(key, cur_modifiers, chordset)
          ChordsetState.key_state_from_downkeys chordset.chords, cur_modifiers, [key], 0
        end
      end # class Idle

      class KeychordDown < ChordsetState
        # @param downkeys [Array<String>] the currently depressed keys
        # @param reachable_chords [Array<Chord>] the set of chords reachable prior to this state
        # @param sequence_index [Integer] the current sequence index
        def initialize(downkeys, reachable_chords, sequence_index)
          @downkeys = downkeys.to_set
          @reachable_chords = reachable_chords
          @sequence_index = sequence_index
        end

        def reachable_chords(_chordset)
          @reachable_chords
        end

        def accept_keydown(key, cur_modifiers, _chordset)
          ChordsetState.key_state_from_downkeys @reachable_chords, cur_modifiers, @downkeys + [key], @sequence_index
        end

        def accept_click(_button, _point, _cur_modifiers, _chordset)
          [DeadEnd.new(@downkeys)]
        end

        def accept_keyup(key, _cur_modifiers, _chordset)
          if @downkeys.include? key
            @downkeys.delete key
            [KeychordUp.new(@downkeys, @reachable_chords, @sequence_index)]
          else
            [DeadEnd.new(@downkeys)]
          end
        end
      end # class KeychordDown

      class KeychordUp < ChordsetState
        # @param downkeys [Enumerable<String>] the currently depressed keys
        # @param reachable_chords [Array<Chord>] the set of chords reachable prior to this state
        # @param sequence_index [Integer] the current sequence index
        def initialize(downkeys, reachable_chords, sequence_index)
          @initial_downkeys = downkeys
          @downkeys = downkeys.to_set
          @sequence_index = sequence_index
          @reachable_chords = reachable_chords
        end

        def reachable_chords(_chordset)
          @reachable_chords
        end

        def accept_keyup(key, cur_modifiers, _chordset)
          if @downkeys.include? key
            @downkeys.delete key
            if @downkeys.empty?
              # Enact any chords we currently matched
              any_enacted = false
              event = EnactEvent.new
              @reachable_chords.each do |chord|
                # This chord was activated if we have the right modifiers and initial downkeys
                if chord.enabled && chord.matches?(cur_modifiers, @initial_downkeys, @sequence_index)
                  chord.enact(event)
                  any_enacted = true
                end
              end
              # If no chords were enacted, we'll wait for a keydown before doing anything. Otherwise, we'll return to
              # the initial state.
              [any_enacted ? Idle.new : self, event.new_mode]
            else
              self
            end
          else
            # We lost track of keys somehow, just fall into the dead end
            [DeadEnd.new(@downkeys)]
          end
        end

        def accept_keydown(key, cur_modifiers, _chordset)
          if @downkeys.empty?
            # Treat this as the start of a new subchord
            ChordsetState.key_state_from_downkeys @reachable_chords, cur_modifiers, [key], @sequence_index + 1
          else
            # We're not expecting this, so we'll move to the dead end
            DeadEnd.new @downkeys + key
          end
        end
      end # class KeychordUp

      class DeadEnd < ChordsetState
        # @param downkeys [Enumerable<String>] the currently depressed keys
        def initialize(downkeys)
          @downkeys = downkeys.to_set
        end

        def reachable_chords(_chordset)
          []
        end

        def accept_modifier_change(cur_modifiers, _chordset)
          if @downkeys.empty? && (cur_modifiers == 0)
            Idle.new
          else
            self
          end
        end

        def accept_keydown(key, _cur_modifiers, _chordset)
          @downkeys << key
          self
        end

        def accept_keyup(key, cur_modifiers, chordset)
          @downkeys.delete key
          [self.accept_modifier_change(cur_modifiers, chordset)]
        end
      end # class DeadEnd
    end # class ChordsetState
  end # module Chords
end # module Crafty
