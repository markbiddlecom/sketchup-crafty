# frozen_string_literal: true

require 'sketchup.rb'

module Crafty
  module Attributes
    CRAFTY_DICTIONARY_NAME = 'Crafty::Attributes::Dictionary'

    ATTRIBUTE_PRIMARY_FACE = 'primary_face'
    ATTRIBUTE_PRIMARY_FACE_VALUE = 'true'

    # Retrieves an attribute from the entity assuming the crafty dictionary
    # @param entity [Sketchup::Entity] the entity from which to retrieve the attribute
    # @param attribute_name [String] the attribute to retrieve
    # @param default_value the default value to return
    # @return the value of the attribute or `default_value` if the attribute is not found
    def self.get_attribute(entity, attribute_name, default_value = nil)
      entity.get_attribute CRAFTY_DICTIONARY_NAME, attribute_name, default_value
    end

    # Sets an entity attribute using the crafty dictionary
    # @param entity [Sketchup::Entity] the entity on which to set the attribute
    # @param attribute_name [String] the attribute to set
    # @param value the attribute's value
    def self.set_attribute(entity, attribute_name, value)
      entity.set_attribute CRAFTY_DICTIONARY_NAME, attribute_name, value
    end

    # Determines whether the given entity has an attribute in the Crafty dictionary with the given name
    # @param entity [Sketchup::Entity] the entity to test
    # @param attribute_name [String] the name of the attribute to find
    # @return [Boolean] `true` if the attribute exists, with any value, and `false` otherwise
    def self.attribute?(entity, attribute_name)
      dict = entity.attribute_dictionary CRAFTY_DICTIONARY_NAME
      dict.nil? ? false : (dict.keys.include? attribute_name)
    end

    # Returns an array of all entities within the given list that have a crafty attribute with the given name
    # @param entities [Enumerable<Sketchup::Entity>] the list of entities to scan
    # @param attribute_name [String] the crafty attribute to use as a filter
    # @return [Array<Sketchup::Entity>] the matching entities
    def self.entities_with_attribute(entities, attribute_name)
      entities.find_all { |e| self.attribute? e, attribute_name }
    end

    # Sets the `"primary_face"` attribute for the given face to `"true"`
    # @param face [Sketchup::Face] the face to tag
    def self.tag_primary_face(face)
      self.set_attribute face, ATTRIBUTE_PRIMARY_FACE, ATTRIBUTE_PRIMARY_FACE_VALUE
    end

    # Returns an array of every face from the given enumerable that has the primary face tag
    # @param entities [Enumerable<Sketchup::Entity>] the list of entities to scan
    # @return [Array<Sketchup::Face>] the matching faces
    def self.find_primary_faces(entities)
      self.entities_with_attribute(entities, ATTRIBUTE_PRIMARY_FACE).grep(Sketchup::Face)
    end
  end # module Attributes
end # module Crafty
