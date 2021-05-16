# Copyright 2016-2019 Trimble Inc
# Licensed under the MIT license

require 'sketchup.rb'
require 'crafty/face_to_panel/tool.rb'

module Crafty
  module Plugin
    unless file_loaded?(__FILE__)
      menu = UI.menu('Plugins')
      submenu = menu.add_submenu('Crafty')
      submenu.add_item('Face To Panel') {
        Crafty::FaceToPanel.start_tool
      }
      file_loaded(__FILE__)
    end
  end # module Plugin
end # module Crafty
