require 'sketchup.rb'
require 'extensions.rb'

module Crafty
  module Plugin

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('Crafty', 'crafty/main')
      ex.description = 'SketchUp plugin with tools to make it easy to work with models for papercraft and interlocking panel projects'
      ex.version     = '0.0.1'
      ex.creator     = 'Mark Biddlecom'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end

  end # module Plugin
end # module Crafty
