divan_path = File.expand_path('../lib', __FILE__)
$:.unshift(divan_path) if File.directory?(divan_path) && !$:.include?(divan_path)

require 'restclient'
require 'json'
require 'divan/models/base'
require 'divan/base'
require 'divan/database'
require 'divan/utils'
require 'yaml'

module Divan
  @@databases = {}

  def self.Model(database_config_name)
    Database.model_class(database_config_name)
  rescue
    Divan::Models::Base
  end

  def self.load_database_configuration(config_path)
    YAML.load(File.read config_path).each do |name, params|
      @@databases[name.to_sym] = Database.new name, params
    end
  end

  def self.[](name)
    @@databases[name.to_sym]
  end

  def self.databases
    @@databases
  end

  class DatabaseNotFound < RuntimeError
    attr_reader :database
    def initialize(database)
      @database = database
    end
  end

  class DatabaseAlreadyCreated < RuntimeError
    attr_reader :database
    def initialize(database)
      @database = database
    end
  end

  class DocumentRevisionMissing < RuntimeError
    attr_reader :document
    def initialize(document)
      @document = document
    end
  end

  class DocumentNotFound < RuntimeError
    attr_reader :document
    def initialize(document)
      @document = document
    end
  end

  class DocumentConflict < RuntimeError
    attr_reader :new_document, :current_document
    def initialize(new_document)
      @new_document = new_document
      @current_document = new_document.class.find new_document.id
    end
  end
end
