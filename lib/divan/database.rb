module Divan
  module Models; end

  class Database
    attr_accessor :name, :host, :port, :database, :user, :password, :views
    def initialize(name, options = {})
      @name, @user, @password = name, options['user'], options['password']
#TODO: Add user & password support
      @host     = options['host'] || 'http://127.0.0.1'
      @port     = options['port'] || 5984
      @database = options['database']
      @views    = {}
      build_model_class
    end

    def exists?
      begin
        client.get
        return true
      rescue RestClient::ResourceNotFound
        return false
      end
    end

    def stats
      begin
        JSON.parse client.get, :symbolize_names => true
      rescue RestClient::ResourceNotFound
        raise Divan::DatabaseNotFound.new(self), "Database was not found"
      end
    end

    def create
      begin
        client.put Hash.new
      rescue RestClient::PreconditionFailed
        raise Divan::DatabaseAlreadyCreated.new(self), "Database already created"
      end
    end

    def delete
      begin
        client.delete
      rescue RestClient::ResourceNotFound
        raise Divan::DatabaseNotFound.new(self), "Database was not found"
      end
    end

    def create_views
      views.each do |name, views|
        create_view(name)
      end
    end

    def create_view(view_name)
      if view_doc = model_class.find("_design/#{view_name}")
        view_doc.views = views[view_name]
        view_doc.save
      else
        model_class.create :id => "_design/#{view_name}", :language => 'javascript', :views => views[view_name]
      end
    end

    def [](path, params={})
      client[ Divan::Utils.formatted_path(path, params) ]
    end

    def client
      @client ||= RestClient::Resource.new( basic_url, *([@user, @password].compact) )
    end

    def model_class
      @model_class ||= eval model_class_full_name
    end

    protected
    def basic_url
      "#{host}:#{port}/#{database}/"
    end

    def model_class_full_name
      "Divan::Models::#{name.to_s.split('_').map{|str| "#{str[0..0].upcase}#{str[1..-1]}" }}"
    end

    def build_model_class
      Divan::Base.class_eval "class #{model_class_full_name} < Divan::Models::Base ; end"
      model_class.database = self
      model_class.name     = name
      model_class.define_view :all, :map => "function(doc){ if(doc._id.slice(0, 7) != \"_design\"){ emit(null, doc) } }"
    end

    def self.model_class(name)
      eval "Divan::Models::#{name.to_s.split('_').map{|str| "#{str[0..0].upcase}#{str[1..-1]}" }}"
    end
  end
end
