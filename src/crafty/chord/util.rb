# frozen_string_literal: true

module Crafty
  module Util
    # Converts the given keycode to the string representation for the current platform
    # @param keycode [Integer] the OS keycode provided
    # @return [String] the character of special key represented by the keycode, or the result of `keycode.to_s` if the
    #   code is not recognized
    def self.keycode_to_key(keycode)
      if @@keymap.nil?
        @@keymap = self.create_keymap
      end
      if @@keymap.include? keycode
        @@keymap[keycode]
      else
        keycode.to_s
      end
    end

    def self.create_keymap
      keymap = {}
      # Common key codes
      keymap[VK_DELETE] = Chords::Chord::DEL
      keymap[VK_INSERT] = Chords::Chord::INS
      keymap[VK_SPACE] = Chords::Chord::SPACE
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
    # @return [void]
    def self.add_win_keycodes(keymap)
      # https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
      # rubocop:disable Style/Semicolon
      keymap[0x09] = Chords::Chord::TAB
      keymap[0x1B] = Chords::Chord::ESCAPE
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
      keymap[0x70] = Chords::Chord::F1; keymap[0x71] = Chords::Chord::F2; keymap[0x72] = Chords::Chord::F3
      keymap[0x73] = Chords::Chord::F4; keymap[0x74] = Chords::Chord::F5; keymap[0x75] = Chords::Chord::F6
      keymap[0x76] = Chords::Chord::F7; keymap[0x77] = Chords::Chord::F8; keymap[0x78] = Chords::Chord::F9
      keymap[0x79] = Chords::Chord::F10; keymap[0x7A] = Chords::Chord::F11; keymap[0x7B] = Chords::Chord::F12
      # rubocop:enable Style/Semicolon
    end

    # @param keymap [Hash] the map to which the codes are added
    # @return [void]
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
      keymap[0x30] = Chords::Chord::TAB
      keymap[0x35] = Chords::Chord::ESCAPE
      # Numpad
      keymap[0x52] = '0'; keymap[0x53] = '1'; keymap[0x54] = '2'; keymap[0x55] = '3'; keymap[0x56] = '4'
      keymap[0x57] = '5'; keymap[0x58] = '6'; keymap[0x59] = '7'; keymap[0x5B] = '8'; keymap[0x5C] = '9'
      # F-keys
      keymap[0x60] = Chords::Chord::F5; keymap[0x61] = Chords::Chord::F6; keymap[0x62] = Chords::Chord::F7
      keymap[0x63] = Chords::Chord::F3; keymap[0x64] = Chords::Chord::F8; keymap[0x65] = Chords::Chord::F9
      keymap[0x67] = Chords::Chord::F11; keymap[0x6D] = Chords::Chord::F10; keymap[0x6F] = Chords::Chord::F12
      keymap[0x76] = Chords::Chord::F4; keymap[0x78] = Chords::Chord::F2; keymap[0x7A] = Chords::Chord::F1
      # rubocop:enable Style/Semicolon
    end
  end # module Util
end # module Crafty
