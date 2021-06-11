# frozen_string_literal: true

# Copyright 2016-2019 Trimble Inc
# Licensed under the MIT license

require 'crafty/chord.rb'
require 'crafty/tool_state_machine.rb'
require 'crafty/util.rb'

require 'crafty/face_to_panel/tool.rb'
require 'crafty/highlight_intersections/tool.rb'
require 'crafty/project_to_plane/tool.rb'

module Crafty
  module Plugin
    unless file_loaded?(__FILE__)
      menu = UI.menu('Plugins')
      submenu = menu.add_submenu('Crafty')
      submenu.add_item('Face To Panel') { FaceToPanel.start_tool }
      submenu.add_item('Highlight Intersections') { HighlightIntersections.start_tool }
      submenu.add_item('Project To Plane') { ProjectToPlane.start_tool }
      file_loaded(__FILE__)
    end

    def self.asset_file(file)
      dir = Kernel.__dir__.dup
      dir.force_encoding('UTF-8') if dir.respond_to?(:force_encoding)
      File.join(dir, 'assets', file)
    end

    def self.load_texture_asset(view, file)
      asset_rep = Sketchup::ImageRep.new(asset_file(file))
      {
        id: view.load_texture(asset_rep),
        width: asset_rep.width,
        height: asset_rep.height,
      }
    end
  end # module Plugin
end # module Crafty
