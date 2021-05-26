# frozen_string_literal: true

require 'crafty/util/clone_face_geometry.rb'
require 'crafty/util/construction.rb'
require 'crafty/util/cycle.rb'
require 'crafty/util/geom.rb'

module Crafty
  module Util
    # Utility method to quickly reload the tutorial files. Useful for development.
    # Can be run from Sketchup's ruby console via entering `Crafty::Util.reload`
    # @return [String] a message describing the result of the reload
    def self.reload
      dir = Kernel.__dir__.dup
      dir.force_encoding('UTF-8') if dir.respond_to?(:force_encoding)
      pattern = File.join(dir, '**/*.rb')
      old_verbose = $VERBOSE
      "Loaded #{
        (
          Dir.glob(pattern).each do |file|
            $VERBOSE = nil
            # Cannot use `Sketchup.load` because its an alias for `Sketchup.require`.
            load file
          ensure
            $VERBOSE = old_verbose
          end
        ).size} file(s)"
    end

    # @param receiver [Object] the object that will receive method calls
    # @param target [Symbol, String]
    def self.method_ref(receiver, target)
      proc do |*args|
        receiver.__send__ target, *args
      end
    end

    # This exists just to wrap Yard types so Solargraph type checking works
    # @param block [Proc] the block to call
    # @return [Object]
    def self.call_block(block, *args)
      # @type [Object]
      ret = block.call(*args)
      ret
    end

    # Pushes an undo operation with the given name and executes the block, committing the operation on success.
    # @param operation_name [String] the text to include in the Undo/Redo history
    # @param suppress [Boolean] set to true to cause the undo operation to be skipped
    # @param block [Proc] the wrapped code to execute
    # @return [Object] the return value of the block
    def self.wrap_with_undo(operation_name, suppress = false, &block)
      return call_block(block) if suppress

      begin
        Sketchup.active_model.start_operation operation_name, true
        call_block(block)
      rescue StandardError
        Sketchup.active_model.abort_operation
        raise $ERROR_INFO
      else
        Sketchup.active_model.commit_operation
      end
    end

    # This method exists to provide Solargraph with type info
    # @param arr [Array]
    # @return [Array<String>]
    def self.arr_to_str_array(arr)
      arr.map(&:to_s)
    end

    # @param input [nil, String, Array<String>, Object, Array<Object>]
    # @return [Array<String>]
    def self.to_str_array(input = nil)
      if input.nil?
        []
      elsif input.is_a? String
        [input]
      elsif input.is_a? Array
        arr_to_str_array input
      else
        [input.to_s]
      end
    end
  end # module Util
end # module Crafty
