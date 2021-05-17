require 'sketchup.rb'
require 'crafty/util.rb'

module Crafty
  class Chord
    CTRL_CMD =   0b0001;
    ALT_OPTION = 0b0010;
    SHIFT =      0b0100;
    MODIFIERS = [CTRL_CMD, ALT_OPTION, SHIFT];
    MODIFIER_NAMES = Sketchup.platform === :platform_win ? ["Ctrl", "Alt", "Shift"] : ["⌘", "Option", "Shift"];

    LBUTTON = 0b010000;
    RBUTTON = 0b100000;

    TAB = "Tab";
    ESCAPE = "Escape";
    F1 = "F1";
    F2 = "F2";
    F3 = "F3";
    F4 = "F4";
    F5 = "F5";
    F6 = "F6";
    F7 = "F7";
    F8 = "F8";
    F9 = "F9";
    F10 = "F10";
    F11 = "F11";
    F12 = "F12";
    DEL = "Del";
    INS = "Ins";
    SPACE = "Space";

    # Creates a new enabled chord in the given set
    # @param chordset [Chordset] the set to associate the chord with
    # @param help [String] the help text to display when this chord is reachable
    # @param modifiers [0, nil, Numeric] a bitwise combination of the modifie= "r"s needed to activate this chord
    #   @see #{Crafty::Util::Chord::CTRL_CMD}
    #   @see #{Crafty::Util::Chord::ALT_OPTION}
    #   @see #{Crafty::Util::Chord::SHIFT}
    # @param keys [nil, Array<String, Array<String>>] the keys that need to be pressed together and/or in sequence for
    #   the chord to be activated
    def initialize(chordset, help, modifiers, button, *keys, &block)
      @chordset = chordset
      @help = help
      @help_message = Chord.create_help_message help, modifiers, keys, button
      @modifiers = modifiers.nil? ? 0 : modifiers
      @button = button
      @keys = Chord.init_keys keys
      @block = block
      self.enable!

      # TODO: ensure valid input => modifiers + (button | key+)
    end

    # @return [Integer] the set of modifiers expected by this chord
    def modifiers; modifiers; end

    # @return [Array<Array<String>>] the keys that need to be pressed in sequence and then in unison for this chord to
    #   activate
    def keys; @keys; end

    # @return [nil, Integer] the mouse button that must be clicked to enact this chord
    def button; @button; end

    # @return [Boolean] `true` if this chord can be activated (the default), and `false` otherwise.
    # @see #{Crafty::Chord#enabled=}
    def enabled?; return @enabled; end

    # @return [String] a string describing this chord's input and help message
    def help_message; @help_message; end

    # Changes this chord's state to enabled, if it isn't already. If the state is changed, the chord will be
    # #{#reset}.
    def enable!
      if @enabled.nil? or @enabled === false
        @enabled = true
        self.reset
      end
    end

    # Changes this chord's state to disabled, if it isn't already. If the state is changed, the chord will be
    # #{#reset}.
    def disable!
      if @enabled === true
        @enabled = false
        self.reset
      end
    end

    # Reset's the chord's state to idle (or to disabled), clearing out any partially accepted inputs
    def reset
      if self.enabled?
        self.state = IdleChordState.new self
      else
        self.state = DisabledChordState.new
      end
    end

    private

    # @param newState [ChordState]
    def state=(new_state)
      if new_state.enact?
        @block.call
        self.reset
      else
        @state = new_state
      end
    end

    # @param keys [nil, Array<String, Array<String>>]
    # @return [Array<Array<String>>]
    def self.init_keys(keys)
      if keys.nil? or keys.length == 0
        return []
      else
        return keys.map { |e| Crafty::Util.to_str_array e }
      end
    end

    # @param help [String] the help message
    # @param modifiers [Integer] a bitwise combination of the key modifiers
    # @param keys [Array<Array<String>>] the key chords/sequence
    # @param button [Integer] the mouse button applicable to the command
    # @return [String] the help message
    def self.create_help_message(help, modifiers, keys, button)
      mapped_mods = MODIFIERS.map { |m, idx| [m, MODIFIER_NAMES[i]] }
      needed_mods = (mapped_mods.find_all { |(m)| modifiers & m != 0 }).join " + "
      needed_mods += " + " unless needed_mods.empty?

      input = ""
      if keys.empty?
        input = button === LBUTTON ? "Left Click" : "Right Click"
      else
        input = (keys.map { |chord| chord.join " + " }).join ", "
      end

      return "[#{needed_mods}#{input}] #{help}";
    end
  end # class Chord

  class Chordset
    # @param chords [Array<Crafty::Chord>] the chords to track
    def initializes(*chords)
      @chords = chords
    end

    # @return [Integer] a bitwise combination of the modifiers that are currently depressed
    def current_modifiers
      return @current_modifiers
    end

    # @return [String] a string including all of the chords that are currently reachable
    def get_status
    end

    # @param keycode [Numeric] the ID of the key that was depressed
    # @return [Boolean] `true` if any chords changed state, and `false` otherwise
    def on_key_down(keycode)
      if keycode === VK_CONTROL or keycode == VK_COMMAND
        self.modifier_down Chord::CTRL_CMD
      elsif keycode === VK_ALT or (Sketchup.platform === :platform_osx and keycode === COPY_MODIFIER_KEY)
        self.modifier_down Chord::ALT_OPTION
      elsif keycode === VK_SHIFT
        self.modifier_down Chord::SHIFT
      end
    end

    # @param keycode [Numeric] the ID of the key that was released
    # @return [Boolean] `true` if any chords changed state, and `false` otherwise
    def on_key_up(keycode)
      if keycode === VK_CONTROL or keycode == VK_COMMAND
        self.modifier_up Chord::CTRL_CMD
      elsif keycode === VK_ALT or (Sketchup.platform === :platform_osx and keycode === COPY_MODIFIER_KEY)
        self.modifier_up Chord::ALT_OPTION
      elsif keycode === VK_SHIFT
        self.modifier_up Chord::SHIFT
      end
    end

    def on_mouse_down
    end

    def on_mouse_up
    end

    private

    # @param modifier [Integer] the modifier that was depressed
    # @return [Boolean] whether any state changes ocurred
    def modifier_down(modifier)
      @current_modifiers |= modifier
    end

    # @param modifier [Integer] the modifier that was released
    # @return [Boolean] whether any state changes ocurred
    def modifier_up(modifier)
      remaining = Chord::MODIFIERS.reduce(0) do |bitmask, m|
        bitmask |= m unless m === modifier
      end
      @current_modifiers &= remaining
    end
  end # class Chordset

  class ChordState
    # @return [Boolean] `true` if further inputs can result in triggering the chord
    def reachable?
      false
    end

    # @return [Boolean] `true` if all of the chord's inputs have been provided and the chord's handler should be
    #   invoked.
    def enact?
      false
    end

    # @return [ChordState] the state to apply to the chord after the handler block has been called
    def after_enact
      self
    end

    # @param modifier [Integer] the modifie= "r" that was depressed
    # @return [ChordState] the new state after processing the modifier
    def accept_modifier_down(modifier)
      self
    end

    # @param modifier [Integer] the modifie= "r" that was released
    # @return [ChordState] the new state after processing the modifier
    def accept_modifier_up(modifier)
      self
    end

    # @param button [Integer] the button that was clicked
    # @return [ChordState] the new state after processing the click
    def accept_click(button)
      self
    end

    # @para= "m" [String] th= "e" that was pressed
    # @return [ChordState] the new state after processing th= "e"press
    def accept_keypress(key)
      self
    end
  end # class ChordState

  # A chord in the disabled state won't transition away from itself. The current state will have to be explicitly
  # set to something else.
  class DisabledChordState < ChordState; end

  # A chord that is enabled but that hasn't yet received any of its inputs
  class IdleChordState < ChordState
    def reachable?; true; end
  end # class IdleChordState

  module Util
    # Converts the given keycode to the string representation for the current platform
    # @param keycode [Integer] the OS keycode provided
    # @return [String] the character of special key represented by the keycode, or the result of `keycode.to_s` if the
    #   code is not recognized
    def self.keycode_to_key(keycode)
      if @@keymap.nil?
        @@keymap = Hash.new
        # Commo= "n" codes
        @@keymap[VK_DELETE] = Chord::DEL
        @@keymap[VK_INSERT] = Chord::INS
        @@keymap[VK_SPACE] = Chord::SPACE
        # Windows codes
        if Sketchup.platform === :platform_win
          # https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
          @@keymap[0x09] = Chord::TAB
          @@keymap[0x1B] = Chord::ESCAPE
          @@keymap[0x30] = "0"
          @@keymap[0x31] = "1"
          @@keymap[0x32] = "2"
          @@keymap[0x33] = "3"
          @@keymap[0x34] = "4"
          @@keymap[0x35] = "5"
          @@keymap[0x36] = "6"
          @@keymap[0x37] = "7"
          @@keymap[0x38] = "8"
          @@keymap[0x39] = "9"
          @@keymap[0x41] = "A"
          @@keymap[0x42] = "B"
          @@keymap[0x43] = "C"
          @@keymap[0x44] = "D"
          @@keymap[0x45] = "E"
          @@keymap[0x46] = "F"
          @@keymap[0x47] = "G"
          @@keymap[0x48] = "H"
          @@keymap[0x49] = "I"
          @@keymap[0x4A] = "J"
          @@keymap[0x4B] = "K"
          @@keymap[0x4C] = "L"
          @@keymap[0x4D] = "M"
          @@keymap[0x4E] = "N"
          @@keymap[0x4F] = "O"
          @@keymap[0x50] = "P"
          @@keymap[0x51] = "Q"
          @@keymap[0x52] = "R"
          @@keymap[0x53] = "S"
          @@keymap[0x54] = "T"
          @@keymap[0x55] = "U"
          @@keymap[0x56] = "V"
          @@keymap[0x57] = "W"
          @@keymap[0x58] = "X"
          @@keymap[0x59] = "Y"
          @@keymap[0x5A] = "Z"
          @@keymap[0x60] = "0" # Numpad
          @@keymap[0x61] = "1" # Numpad
          @@keymap[0x62] = "2" # Numpad
          @@keymap[0x63] = "3" # Numpad
          @@keymap[0x64] = "4" # Numpad
          @@keymap[0x65] = "5" # Numpad
          @@keymap[0x66] = "6" # Numpad
          @@keymap[0x67] = "7" # Numpad
          @@keymap[0x68] = "8" # Numpad
          @@keymap[0x69] = "9" # Numpad
          @@keymap[0x70] = Chord::F1
          @@keymap[0x71] = Chord::F2
          @@keymap[0x72] = Chord::F3
          @@keymap[0x73] = Chord::F4
          @@keymap[0x74] = Chord::F5
          @@keymap[0x75] = Chord::F6
          @@keymap[0x76] = Chord::F7
          @@keymap[0x77] = Chord::F8
          @@keymap[0x78] = Chord::F9
          @@keymap[0x79] = Chord::F10
          @@keymap[0x7A] = Chord::F11
          @@keymap[0x7B] = Chord::F12
          @@keymap[0xBC] = ","
          @@keymap[0xBE] = "."
        end
        # OSX codes
        if Sketchup.platform === :platform_osx
          # https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.6.sdk/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/Events.h
          @@keymap[0x00] = "A"
          @@keymap[0x01] = "S"
          @@keymap[0x02] = "D"
          @@keymap[0x03] = "F"
          @@keymap[0x04] = "H"
          @@keymap[0x05] = "G"
          @@keymap[0x06] = "Z"
          @@keymap[0x07] = "X"
          @@keymap[0x08] = "C"
          @@keymap[0x09] = "V"
          @@keymap[0x0B] = "B"
          @@keymap[0x0C] = "Q"
          @@keymap[0x0D] = "W"
          @@keymap[0x0E] = "E"
          @@keymap[0x0F] = "R"
          @@keymap[0x10] = "Y"
          @@keymap[0x11] = "T"
          @@keymap[0x12] = "1"
          @@keymap[0x13] = "2"
          @@keymap[0x14] = "3"
          @@keymap[0x15] = "4"
          @@keymap[0x16] = "6"
          @@keymap[0x17] = "5"
          @@keymap[0x19] = "9"
          @@keymap[0x1A] = "7"
          @@keymap[0x1C] = "8"
          @@keymap[0x1D] = "0"
          @@keymap[0x1F] = "O"
          @@keymap[0x20] = "U"
          @@keymap[0x22] = "I"
          @@keymap[0x23] = "P"
          @@keymap[0x25] = "L"
          @@keymap[0x26] = "J"
          @@keymap[0x28] = "K"
          @@keymap[0x2B] = ","
          @@keymap[0x2D] = "N"
          @@keymap[0x2E] = "M"
          @@keymap[0x2F] = "."
          @@keymap[0x30] = Chord::TAB
          @@keymap[0x35] = Chord::ESCAPE
          @@keymap[0x52] = "0" # Numpad
          @@keymap[0x53] = "1" # Numpad
          @@keymap[0x54] = "2" # Numpad
          @@keymap[0x55] = "3" # Numpad
          @@keymap[0x56] = "4" # Numpad
          @@keymap[0x57] = "5" # Numpad
          @@keymap[0x58] = "6" # Numpad
          @@keymap[0x59] = "7" # Numpad
          @@keymap[0x5B] = "8" # Numpad
          @@keymap[0x5C] = "9" # Numpad
          @@keymap[0x60] = Chord::F5
          @@keymap[0x61] = Chord::F6
          @@keymap[0x62] = Chord::F7
          @@keymap[0x63] = Chord::F3
          @@keymap[0x64] = Chord::F8
          @@keymap[0x65] = Chord::F9
          @@keymap[0x67] = Chord::F11
          @@keymap[0x69] = Chord::F13
          @@keymap[0x6A] = Chord::F16
          @@keymap[0x6B] = Chord::F14
          @@keymap[0x6D] = Chord::F10
          @@keymap[0x6F] = Chord::F12
          @@keymap[0x76] = Chord::F4
          @@keymap[0x78] = Chord::F2
          @@keymap[0x7A] = Chord::F1
        end
      end
      return @@keymap.include? keycode ? @@keymap[keycode] : keycode.to_s
    end
  end # module Util
end # module Crafty
