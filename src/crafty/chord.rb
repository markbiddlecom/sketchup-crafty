# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/tool_state_machine.rb'
require 'crafty/util.rb'

module Crafty
  class Chord
    CTRL_CMD =   0b0001
    ALT_OPTION = 0b0010
    SHIFT =      0b0100
    MODIFIERS = [CTRL_CMD, ALT_OPTION, SHIFT].freeze
    MODIFIER_NAMES = Sketchup.platform == :platform_win ? %w[Ctrl Alt Shift] : %w[⌘ Option Shift]

    LBUTTON = 0b00010000
    RBUTTON = 0b00100000
    LDRAG =   0b01000000
    RDRAG =   0b10000000

    TAB = 'Tab'
    ESCAPE = 'Escape'
    F1 = 'F1'
    F2 = 'F2'
    F3 = 'F3'
    F4 = 'F4'
    F5 = 'F5'
    F6 = 'F6'
    F7 = 'F7'
    F8 = 'F8'
    F9 = 'F9'
    F10 = 'F10'
    F11 = 'F11'
    F12 = 'F12'
    DEL = 'Del'
    INS = 'Ins'
    SPACE = 'Space'

    # Creates a new enabled chord in the given set
    # @param chordset [Chordset] the set to associate the chord with
    # @param cmd [Symbol] the name of the chord's command
    # @param help [String] the help text to display when this chord is reachable
    # @param modifiers [0, nil, Numeric] a bitwise combination of the modifier keys needed to activate this chord
    #   @see #{Crafty::Util::Chord::CTRL_CMD}
    #   @see #{Crafty::Util::Chord::ALT_OPTION}
    #   @see #{Crafty::Util::Chord::SHIFT}
    # @param button [Integer] the mouse button that must be clicked for the command to be activated
    # @param keys [nil, Array<String, Array<String>>] the keys that need to be pressed together and/or in sequence for
    #   the chord to be activated
    # @param block [Proc] the code to execute when the command is triggered
    def initialize(chordset, cmd, help, modifiers, button, *keys, &block)
      @chordset = chordset
      @cmd = cmd
      @help = help
      @help_message = Chord.create_help_message help, modifiers, keys, button
      @modifiers = modifiers.nil? ? 0 : modifiers
      @antimodifiers = ~@modifiers
      @button = button
      @keys = Chord.init_keys keys
      @block = block
      # TODO: ensure valid input => modifiers? (button | key+)
    end

    # @return [Symbol] the chord's command name
    attr_reader :cmd

    # @return [Integer] the set of modifiers expected by this chord
    attr_reader :modifiers

    # @return [Integer] the set of modifiers that disqualify this chord
    attr_reader :antimodifiers

    # @return [Array<Array<String>>] the keys that need to be pressed in sequence and then in unison for this chord to
    #   activate
    attr_reader :keys

    # @return [nil, Integer] the mouse button that must be clicked to enact this chord
    attr_reader :button

    # @return [String] a string describing this chord's input and help message
    attr_reader :help_message

    # @return [Boolean] whether this command is allowed to be enacted
    attr_reader :enabled

    # @param new_enabled [Boolean] the new enabled state
    attr_writer :enabled

    # @param cur_modifiers [Integer] the currently activated modifier keys
    # @param downkeys [Enumerable<String>] the currently depressed (non-modifier) keys
    # @param sequence_index [Integer] the index of the subchord within `keys` to compare `downkeys` with
    # @return [Boolean] `true` if this chord's configuration matches the given parameters.
    def matches?(cur_modifiers, downkeys, sequence_index)
      (cur_modifiers == @modifiers &&
        sequence_index == @keys.length - 1 &&
        (downkeys.to_set | @keys[sequence_index]).length == @keys[sequence_index].length)
    end

    # @return [Boolean] `true` if this chord can be activated (the default), and `false` otherwise.
    # @see #{Crafty::Chord#enabled=}
    def enabled?
      @enabled
    end

    # Invokes this chord's block
    def enact(event)
      @block.call self, event
    end

    # @param keys [nil, Array<String, Array<String>>]
    # @return [Array<Array<String>>]
    def self.init_keys(keys)
      if keys.nil? || (keys.length == 0)
        []
      else
        keys.map { |e| Crafty::Util.to_str_array e }
      end
    end

    # @param help [String] the help message
    # @param modifiers [Integer] a bitwise combination of the key modifiers
    # @param keys [Array<Array<String>>] the key chords/sequence
    # @param button [Integer] the mouse button applicable to the command
    # @return [String] the help message
    def self.create_help_message(help, modifiers, keys, button)
      mapped_mods = MODIFIERS.map.with_index { |m, idx| [m, MODIFIER_NAMES[idx]] }
      needed_mods = (mapped_mods.find_all { |(m)| modifiers & m != 0 }).join ' + '
      needed_mods += ' + ' unless needed_mods.empty?
      input = ''
      if keys.empty?
        input = button == LBUTTON ? 'Left Click' : 'Right Click'
      else
        input = (keys.map { |chord| chord.join ' + ' }).join ', '
      end
      "[#{needed_mods}#{input}] #{help}"
    end

    # An `each` implementation for an enumerable of chords. This is just here to forward on type info to yard.
    # @param chords [Enumerable<Chord>]
    # @yield [chord] yields for each chord in the function
    # @yieldparam chord [Chord] an individual element from `chords`
    def self.iterate_chords(chords, &block)
      chords.each(&block)
    end

    # @return [Proc]
    # @yield [chord, event] called when a chord's command is enacted
    # @yieldparam chord [Chord] the chord that was enacted
    # @yieldparam event [EnactEvent, ClickEnactEvent, DragEnactEvent] an event describing the cause of the enactment
    def self.event_handler(&block)
      block
    end
  end # class Chord

  class EnactEvent
    # @return [nil, Crafty::ToolStateMachine::Mode] this can optionally be set to a non-`nil` value by
    #   the event handler to indicate that the
    attr_reader :new_state
  end # class EnactEvent

  class ClickEnactEvent < EnactEvent
    # @param x [Numeric] the x-coordinate where the mouse was clicked
    # @param y [Numeric] the y-coordinate where the mouse was clicked
    def initialize(x, y)
      @x = x
      @y = y
    end

    # @return [Numeric] the x-coordinate where the mouse was clicked
    attr_reader :x

    # @return [Numeric] the y-coordinate where the mouse was clicked
    attr_reader :y
  end # class ClickEnactEvent

  class DragEnactEvent < EnactEvent
    # @param x_start [Numeric] the x-coordinate where the user started dragging
    # @param y_start [Numeric] the y-coordinate where the user started dragging
    # @param x_end [Numeric] the x-coordinate where the user ended dragging
    # @param y_end [Numeric] the y-coordinate where the user ended dragging
    def initialize(x_start, y_start, x_end, y_end)
      @bounds = Geom::Bounds2d.new(
          [x_start, x_end].min, [y_start, y_end].min,
          (x_end - x_start).abs, (y_end - y_start).abs
        )
      @direction = x_end >= x_start ? :left_to_right : :right_to_left
    end

    # @return [Geom::Bounds2d] the bounds of the rectangle dragged by the user
    attr_reader :bounds

    # @return [:left_to_right, :right_to_left] `:left_to_right` if the user started drawing the rectangle on the
    #   left side and `:right_to_left` otherwise.
    attr_reader :direction
  end # DragEnactEvent

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
      @current_modifiers = 0
      @state = ChordsetState::Idle.new
    end

    # @return [Integer] a bitwise combination of the modifiers that are currently depressed
    attr_reader :current_modifiers

    # @return [Array<Chord>] the chords associated with this chordset
    attr_reader :chords

    # @return [String] a string including all of the chords that are currently reachable
    def status
      @chords.find_all(&:reachable?).map(&:help_message).join('; ')
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
    # @param cur_modifiers [Integer] the current state of modifier keys
    # @param chordset [Chordset] the chordset processing the event
    # @return [ChordsetState] the new state after processing the click
    def accept_click(_button, _cur_modifiers, _chordset)
      self
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
    # @return [ChordsetState] the new state after processing the released key
    def accept_keyup(_key, _cur_modifiers, _chordset)
      self
    end

    # @param available_chords [Array<Chord>] the chords that are reachable before filtering
    # @param cur_modifiers [Integer] the current state of the modifier keys
    # @param downkeys [Array<String>] the currently depressed keys (other than the modifier keys)
    # @param sequence_index [Integer] the current sequence index a multi-step chord
    # @return [ChordsetState] the activated state given the current set of reachable chords
    def self.key_state_from_downkeys(available_chords, cur_modifiers, downkeys, sequence_index)
      reachable_chords = available_chords.find_all do |chord|
        if chord.enabled? && (chord.modifiers == cur_modifiers) && (chord.button == 0)
          # This chord is still reachable if it has a key sequence with the given index and if the current set of
          # downkeys doesn't contain any keys not expected by the chord
          if chord.keys.length > sequence_index
            sequence_keys = chord.keys[sequence_index].to_set
            return downkeys.all? { |key| sequence_keys.include? key }
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
      def accept_click(button, cur_modifiers, chordset)
        chordset.chords.each do |chord|
          chord.enact if chord.enabled? && chord.modifiers == cur_modifiers && chord.button == button
        end
        self
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

      def accept_click(_button, _cur_modifiers, _chordset)
        DeadEnd.new @downkeys
      end

      def accept_keyup(key, _cur_modifiers, _chordset)
        if @downkeys.include? key
          @downkeys.delete key
          KeychordUp.new @downkeys, @reachable_chords, @sequence_index
        else
          DeadEnd.new @downkeys
        end
      end
    end # class KeychordDown

    class KeychordUp < ChordsetState
      # @param downkeys [Enumerable<String>] the currently depressed keys
      # @param reachable_chords [Array<Chord>] the set of chords reachable prior to this state
      # @param sequence_index [Integer] the current sequence index
      def initialize(downkeys, _reachable_chords, sequence_index)
        @initial_downkeys = downkeys
        @downkeys = downkeys.to_set
        @sequence_index = sequence_index
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
            Crafty::Chord.iterate_chords(@reachable_chords) do |chord|
              # This chord was activated if we have the right modifiers and initial downkeys
              if chord.enabled? && chord.matches?(cur_modifiers, @initial_downkeys, @sequence_index)
                chord.enact
                any_enacted = true
              end
            end
            # If no chords were enacted, we'll wait for a keydown before doing anything. Otherwise, we'll return to the
            # initial state.
            any_enacted ? Idle.new : self
          else
            self
          end
        else
          # We lost track of keys somehow, just fall into the dead end
          DeadEnd.new @downkeys
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
      # @param downkeys [Array<String>] the currently depressed keys
      def initialize(downkeys)
        @downkeys = downkeys.to_set
      end

      def reachable_chords(_chordset)
        []
      end

      def accept_modifier_change(cur_modifiers, _chordset)
        if downkeys.empty? && (cur_modifiers == 0)
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
        self.accept_modifier_change cur_modifiers, chordset
      end
    end # class DeadEnd
  end # class ChordsetState

  module Util
    # Converts the given keycode to the string representation for the current platform
    # @param keycode [Integer] the OS keycode provided
    # @return [String] the character of special key represented by the keycode, or the result of `keycode.to_s` if the
    #   code is not recognized
    def self.keycode_to_key(keycode)
      if @@keymap.nil?
        @@keymap = self.create_keymap
      end
      @@keymap.include? keycode ? @@keymap[keycode] : keycode.to_s
    end

    def self.create_keymap
      keymap = {}
      # Common key codes
      keymap[VK_DELETE] = Chord::DEL
      keymap[VK_INSERT] = Chord::INS
      keymap[VK_SPACE] = Chord::SPACE
      # Windows codes
      if Sketchup.platform == :platform_win
        self.add_win_keycodes keymap
      end
      # OSX codes
      if Sketchup.platform == :platform_osx
        self.add_osx_keycodes keymap
      end
      keymap
    end

    # @param keymap [Hash] the map to which the codes are added
    def self.add_win_keycodes(keymap)
      # https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
      # rubocop:disable Style/Semicolon
      keymap[0x09] = Chord::TAB
      keymap[0x1B] = Chord::ESCAPE
      keymap[0x30] = '0'; keymap[0x31] = '1'; keymap[0x32] = '2'; keymap[0x33] = '3'; keymap[0x34] = '4'
      keymap[0x35] = '5'; keymap[0x36] = '6'; keymap[0x37] = '7'; keymap[0x38] = '8'; keymap[0x39] = '9'
      keymap[0x41] = 'A'; keymap[0x42] = 'B'; keymap[0x43] = 'C'; keymap[0x44] = 'D'; keymap[0x45] = 'E'
      keymap[0x46] = 'F'; keymap[0x47] = 'G'; keymap[0x48] = 'H'; keymap[0x49] = 'I'; keymap[0x4A] = 'J'
      keymap[0x4B] = 'K'; keymap[0x4C] = 'L'; keymap[0x4D] = 'M'; keymap[0x4E] = 'N'; keymap[0x4F] = 'O'
      keymap[0x50] = 'P'; keymap[0x51] = 'Q'; keymap[0x52] = 'R'; keymap[0x53] = 'S'; keymap[0x54] = 'T'
      keymap[0x55] = 'U'; keymap[0x56] = 'V'; keymap[0x57] = 'W'; keymap[0x58] = 'X'; keymap[0x59] = 'Y'
      keymap[0x5A] = 'Z'; keymap[0xBC] = ','; keymap[0xBE] = '.'
      # Numpad
      keymap[0x60] = '0'; keymap[0x61] = '1'; keymap[0x62] = '2'; keymap[0x63] = '3'; keymap[0x64] = '4'
      keymap[0x65] = '5'; keymap[0x66] = '6'; keymap[0x67] = '7'; keymap[0x68] = '8'; keymap[0x69] = '9'
      # F-keys
      keymap[0x70] = Chord::F1; keymap[0x71] = Chord::F2; keymap[0x72] = Chord::F3; keymap[0x73] = Chord::F4
      keymap[0x74] = Chord::F5; keymap[0x75] = Chord::F6; keymap[0x76] = Chord::F7; keymap[0x77] = Chord::F8
      keymap[0x78] = Chord::F9; keymap[0x79] = Chord::F10; keymap[0x7A] = Chord::F11; keymap[0x7B] = Chord::F12
      # rubocop:enable Style/Semicolon
    end

    def self.add_osx_keycodes(keymap)
      # https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.6.sdk/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/Events.h
      # rubocop:disable Style/Semicolon
      keymap[0x00] = 'A'; keymap[0x01] = 'S'; keymap[0x02] = 'D'; keymap[0x03] = 'F'; keymap[0x04] = 'H'
      keymap[0x05] = 'G'; keymap[0x06] = 'Z'; keymap[0x07] = 'X'; keymap[0x08] = 'C'; keymap[0x09] = 'V'
      keymap[0x0B] = 'B'; keymap[0x0C] = 'Q'; keymap[0x0D] = 'W'; keymap[0x0E] = 'E'; keymap[0x0F] = 'R'
      keymap[0x10] = 'Y'; keymap[0x11] = 'T'; keymap[0x12] = '1'; keymap[0x13] = '2'; keymap[0x14] = '3'
      keymap[0x15] = '4'; keymap[0x16] = '6'; keymap[0x17] = '5'; keymap[0x19] = '9'; keymap[0x1A] = '7'
      keymap[0x1C] = '8'; keymap[0x1D] = '0'; keymap[0x1F] = 'O'; keymap[0x20] = 'U'; keymap[0x22] = 'I'
      keymap[0x23] = 'P'; keymap[0x25] = 'L'; keymap[0x26] = 'J'; keymap[0x28] = 'K'; keymap[0x2B] = ','
      keymap[0x2D] = 'N'; keymap[0x2E] = 'M'; keymap[0x2F] = '.'
      keymap[0x30] = Chord::TAB
      keymap[0x35] = Chord::ESCAPE
      # Numpad
      keymap[0x52] = '0'; keymap[0x53] = '1'; keymap[0x54] = '2'; keymap[0x55] = '3'; keymap[0x56] = '4'
      keymap[0x57] = '5'; keymap[0x58] = '6'; keymap[0x59] = '7'; keymap[0x5B] = '8'; keymap[0x5C] = '9'
      # F-keys
      keymap[0x60] = Chord::F5; keymap[0x61] = Chord::F6; keymap[0x62] = Chord::F7; keymap[0x63] = Chord::F3
      keymap[0x64] = Chord::F8; keymap[0x65] = Chord::F9; keymap[0x67] = Chord::F11; keymap[0x69] = Chord::F13
      keymap[0x6A] = Chord::F16; keymap[0x6B] = Chord::F14; keymap[0x6D] = Chord::F10; keymap[0x6F] = Chord::F12
      keymap[0x76] = Chord::F4; keymap[0x78] = Chord::F2; keymap[0x7A] = Chord::F1
      # rubocop:enable Style/Semicolon
    end
  end # module Util
end # module Crafty
