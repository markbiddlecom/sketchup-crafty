# frozen_string_literal: true

# Copyright 2016-2019 Trimble Inc
# Licensed under the MIT license

require 'crafty/chord.rb'
require 'crafty/tool_state_machine.rb'
require 'crafty/util.rb'
require 'crafty/face_to_panel/tool.rb'
require 'crafty/project_to_plane/tool.rb'

module Crafty
  module Plugin
    unless file_loaded?(__FILE__)
      menu = UI.menu('Plugins')
      submenu = menu.add_submenu('Crafty')
      submenu.add_item('Face To Panel') { Crafty::FaceToPanel.start_tool }
      submenu.add_item('Project To Plane') { Crafty::ProjectToPlane.start_tool }
      file_loaded(__FILE__)
    end
  end # module Plugin
end # module Crafty
