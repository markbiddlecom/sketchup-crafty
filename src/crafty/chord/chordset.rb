# frozen_string_literal: true

module Crafty
  module Chords
    class Chordset
      # @param chords [Array<Hash>] initialization parameters for the chords to track
      # @options chords [Symbol] :cmd the unique symbol for this command
      # @options chords [String] :help the help message to display to users when this chord is available
      # @options chords [Integer] :modifiers the set of modifier keys that must be depressed to enact this chord
      # @options chords [Integer, String, Array<String, Array<String>>] :trigger either `Chord::LBUTTON`,
      #   `Chord::RBUTTON`, or the key or key sequence that must be pressed to trigger the command
      # @options chords [Proc] :on_trigger the code to execute when the command is triggered
      def initialize(*chords)
        @chords = Chordset.chords_from_hashes self, chords
      end

      # @return [Integer] a bitwise combination of the modifiers that are currently depressed
      attr_reader :current_modifiers

      # @return [Array<Chord>] the chords associated with this chordset
      attr_reader :chords

      # @return [String] a string including all of the chords that are currently reachable
      def status
        # @type [Array<String>]
        help_messages = @chords.find_all(&:reachable?).map(&:help_message)
        help_messages.join(' // ')
      end

      # @return [Chordset] this chordset
      def reset!
        @current_modifiers = 0
        @state = ChordsetState::Idle.new
        self
      end

      # @param command [Symbol] the ID of the command to enable
      def enable!(command); end

      # @param command [Symbol] the ID of the command to disable
      def disable!(command); end

      # @param keycode [Numeric] the ID of the key that was depressed
      # @return [Boolean] `true` if any chords changed state, and `false` otherwise
      def on_keydown(keycode)
        modifier = self.keycode_to_modifier keycode
        if modifier.nil?
          key = Util.keycode_to_key keycode
          self.apply_state @state.accept_keydown(key, @current_modifiers, self)
        else
          self.modifier_down modifier
        end
      end

      # @param keycode [Numeric] the ID of the key that was released
      # @return [Boolean] `true` if any chords changed state, and `false` otherwise
      def on_keyup(keycode)
        modifier = self.keycode_to_modifier keycode
        if modifier.nil?
          key = Util.keycode_to_key keycode
          self.apply_state @state.accept_keyup(key, @current_modifiers, self)
        else
          self.modifier_up modifier
        end
      end

      # @param button [Numeric] the ID of the button that was clicked.
      #   @see #{Crafty::Chord.LBUTTON}
      #   @see #{Crafty::Chord.RBUTTON}
      # @return [Boolean] `true` if the reachable chords changed state, and `false` otherwise
      def on_click(button)
        self.apply_state @state.accept_click(button, @current_modifiers, self)
      end

      # @param chordset [Chordset] the chordset to associate the chords with
      # @param chords [Array<Hash>] the initialization options for the chords
      # @return [Array<Chord>] the initialized chords
      def self.chords_from_hashes(chordset, chords)
        chords.map do |chord_hash|
          trigger = chord_hash[:trigger]
          Chord.new(
              chordset,
              chord_hash[:cmd],
              chord_hash[:help],
              chord_hash[:modifiers] || 0,
              trigger.is_a?(Numeric) ? trigger : 0,
              *(trigger.is_a?(Numeric) ? [] : trigger),
              &(chord_hash[:on_trigger])
            )
        end
      end

      # @param keycode [Numeric] the key in question
      # @return [nil, Numeric] the modifier key that maps to `keycode`, or `nil` if `keycode` does not represent a
      #   modifier
      def self.keycode_to_modifier(keycode)
        if (keycode == VK_CONTROL) || (keycode == VK_COMMAND)
          Chord::CTRL_CMD
        elsif (keycode == VK_ALT) || ((Sketchup.platform == :platform_osx) && (keycode == COPY_MODIFIER_KEY))
          Chord::ALT_OPTION
        elsif keycode == VK_SHIFT
          Chord::SHIFT
        end
      end

      private

      # @param new_state [ChordsetState] the state to apply
      # @return [Boolean] whether the state actually changed
      def apply_state(new_state)
        if new_state != @state
          @state = new_state
          true
        else
          false
        end
      end

      # @param modifier [Integer] the modifier that was depressed
      # @return [Boolean] whether any state changes occurred
      def modifier_down(modifier)
        @current_modifiers |= modifier
        self.trigger_modifier_change
      end

      # @param modifier [Integer] the modifier that was released
      # @return [Boolean] whether any state changes occurred
      def modifier_up(modifier)
        @current_modifiers &= ~modifier
        self.trigger_modifier_change
      end

      # @return [Boolean] whether any state changes occurred
      def trigger_modifier_change
        self.apply_state @state.accept_modifier_change @current_modifiers, self
      end
    end # class Chordset
  end # module Chords
end # module Crafty
