# frozen_string_literal: true

require 'sketchup.rb'
require 'crafty/util/util.rb'

module Crafty
  module Chords
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
      # @param modifiers [Numeric] a bitwise combination of the modifier keys needed to activate this chord
      #   @see #{Crafty::Util::Chord::CTRL_CMD}
      #   @see #{Crafty::Util::Chord::ALT_OPTION}
      #   @see #{Crafty::Util::Chord::SHIFT}
      # @param button [Integer] the mouse button that must be clicked for the command to be activated
      # @param keys [Array<String, Array>] the keys that need to be pressed together and/or in sequence for
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
      attr :enabled?

      # @param cur_modifiers [Integer] the currently activated modifier keys
      # @param downkeys [Enumerable<String>] the currently depressed (non-modifier) keys
      # @param sequence_index [Integer] the index of the subchord within `keys` to compare `downkeys` with
      # @return [Boolean] `true` if this chord's configuration matches the given parameters.
      def matches?(cur_modifiers, downkeys, sequence_index)
        if sequence_index == @keys.length - 1
          sequence_keys = @keys[sequence_index]
          (cur_modifiers == @modifiers && (downkeys.to_set | @keys[sequence_index]).length == sequence_keys.length)
        else
          false
        end
      end

      # Invokes this chord's block
      # @param event [EnactEvent] details about the event
      # @return [void]
      def enact(event)
        @block.call self, event
      end

      # @param keys [Array<String, Array>]
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
      # @param keys [Array<Array>] the key chords/sequence
      # @param button [Integer] the mouse button applicable to the command
      # @return [String] the help message
      def self.create_help_message(help, modifiers, keys, button)
        mapped_mods = MODIFIERS.map.with_index { |m, idx| [m, MODIFIER_NAMES[idx]] }
        needed_mods = (mapped_mods.find_all { |tuple| modifiers & tuple[0] != 0 }).join ' + '
        needed_mods += ' + ' unless needed_mods.empty?
        input = ''
        if keys.empty?
          input = button == LBUTTON ? 'Left Click' : 'Right Click'
        else
          input = (keys.map { |chord| chord.join ' + ' }).join ', '
        end
        "[#{needed_mods}#{input}] #{help}"
      end

      # @return [Proc]
      # @yield [chord, event] called when a chord's command is enacted
      # @yieldparam chord [Chord] the chord that was enacted
      # @yieldparam event [EnactEvent, ClickEnactEvent, DragEnactEvent] an event describing the cause of the enactment
      def self.event_handler(&block)
        block
      end
    end # class Chord
  end # module Chord
end # module Crafty
