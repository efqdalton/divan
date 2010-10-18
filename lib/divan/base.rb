module Divan
  class Base
    attr_accessor :id, :rev, :attributes, :last_request

    def initialize(opts = {})
      opts = opts.clone
      @id  = opts.delete(:id)  || opts.delete(:_id) || Divan::Utils.uuid
      @rev = opts.delete(:rev) || opts.delete(:_rev)
      @attributes = opts
      self.class.properties.each{ |property| @attributes[property] ||= nil }
    end

    def [](key)
      @attributes[key]
    end

    def []=(key, value)
      @attributes[key] = value
    end

    def save
      self.class.execute_before_validate_callback(self) or return false

      validate or return false

      self.class.execute_after_validate_callback(self)  or return false
      self.class.execute_before_save_callback(self)     or return false

      execute_save

      self.class.execute_after_save_callback(self)
      @last_request
    end

    def delete
      begin
        @last_request = database.client[current_document_path].delete
      rescue RestClient::ResourceNotFound
        @last_request = nil
        return @last_request
      end
      @rev = JSON.parse(@last_request, :symbolize_names => true )[:rev]
      @last_request
    end

    def validate
      true
    end
    alias :"valid?" :validate 

    def database
      self.class.database
    end

    def revision_ids
      begin
        @last_request = database.client[document_path :revs_info => true].get
        JSON.parse(@last_request, :symbolize_names => true )[:_revs_info].find_all{ |hash| hash[:status] == 'available' }.map{ |hash| hash[:rev] }
      rescue RestClient::ResourceNotFound
        return []
      end
    end

    def revision(index)
      r = revision_ids.find{ |rev| rev[0..1].to_i == index}
      return nil if r.nil?
      return self if r == @rev
      self.class.find @id, :rev => r
    end

    def revision!(index)
      r = revision_ids.find{ |rev| rev[0..1].to_i == index}
      r.nil? and raise Divan::Divan::DocumentRevisionNotAvailable.new(self), "Revision with index #{index} missing"
      return self if r == @rev
      self.class.find @id, :rev => r
    end

    def method_missing(method, *args, &block)
      method = method.to_s
      if method[-1..-1] == '='
        attrib = method[0..-2].to_sym
        return @attributes[attrib] = args.first
      end
      if( @attributes.keys.include?( (attrib = method[0..-1].to_sym) ) )
        return @attributes[attrib]
      end
      super
    end

    def to_s
      "\#<#{database.name.to_s.split('_').map{|str| "#{str[0..0].upcase}#{str[1..-1]}" }} #{@attributes.inspect.gsub("\\\"", "\"")}>"
    end
    alias :inspect :to_s

    protected

    def document_path(params = {})
      Divan::Utils.formatted_path @id, params
    end

    def current_document_path(params = {})
      params[:rev] = @rev if @rev
      document_path params
    end

    def execute_save
      begin
        save_attrs = @attributes.clone
        save_attrs[:"_rev"] = @rev if @rev
        @last_request = database.client[current_document_path].put save_attrs.to_json
        @rev = JSON.parse(@last_request, :symbolize_names => true )[:rev]
      rescue RestClient::Conflict
        raise Divan::DocumentConflict.new(self), "Update race conflict"
      end
    end

    class << self
      attr_writer :database, :name
      attr_reader :view_by_params

      def properties(*args)
        unless @properties
          @properties = ( superclass.properties.nil? ) ? [] : superclass.properties
        end
        @properties.concat args.flatten!
        @properties
      end

      def database
        @database ||= superclass.database
      end

      def name
        @name ||= superclass.name
      end

      [:before_save, :after_save, :before_create, :after_create, :before_validate, :after_validate].each do |method|
        define_method method do |param|
          eval "( @#{method}_callback ||= [] ) << param"
        end

        define_method "execute_#{method}_callback" do |instance|
          eval <<-end_txt
            @#{method}_callback ||= []
            !!@#{method}_callback.each do |cb|
              instance.send(cb) or break false if cb.is_a?(Symbol)
              cb.call(instance) or break false if cb.is_a?(Proc)
            end
          end_txt
        end

      end

      def find_all(params=nil)
        query_view :all, params
      end

      def all
        find_all
      end

      def delete_all(params = nil)
        to_be_deleted = find_all(params).map do |object|
          {:_id => object.id, :_rev => object.rev, :_deleted => true }
        end
        payload = { :docs => to_be_deleted }.to_json
        database.client['_bulk_docs'].post payload, :content_type => :json, :accept => :json
        to_be_deleted.size
      end

      def find(id, params = {})
        begin
          last_request = database.client[Divan::Utils.formatted_path id, params].get
        rescue RestClient::ResourceNotFound
          return nil
        end
        attributes = JSON.parse last_request, :symbolize_names => true
        obj = self.new attributes
        obj.last_request = last_request
        obj
      end

      def create(opts = {})
        raise ArgumentError if( !opts.is_a?(Hash) && !opts.is_a?(Array) )
        if opts.is_a? Hash
          single_create opts
        else
          bulk_create opts
        end
      end

      def define_view(param, functions)
        database.views[name] ||= {}
        database.views[name][param] = functions
      end

      def query_view(view, key=nil, args={}, special={})
        if key.is_a? Hash
          special = args
          args    = key
        else
          special = args
          args    = {:key => key}
        end

        args = args.inject({}){ |hash,(k,v)| hash[k] = v.to_json; hash }
        view_path = Divan::Utils.formatted_path "_design/#{name}/_view/#{view}", args.merge(special)
        last_request = database.client[view_path].get
        results = JSON.parse last_request, :symbolize_names => true
        results[:rows].map do |row|
          obj = self.new row[:value]
          obj.last_request = last_request 
          obj
        end
      end

      protected

      def view_by(param)
        @view_by_params ||= []
        @view_by_params << param
        add_view_to_be_created param
        eval <<-end_txt
          class << self
            def all_by_#{param}(key, args={}, special={})
              query_view :by_#{param}, key, args, special
            end

            def by_#{param}(key)
              all_by_#{param}(:key => key, :limit => 1).first
            end
          end
        end_txt
      end

      def add_view_to_be_created(param)
        database.views[name] ||= {}
        database.views[name][:"by_#{param}"] = { :map => "function(doc) { emit(doc.#{param}, doc) }" }
      end

      def single_create(opts = {})
        obj = self.new(opts)
        obj.save
        obj
      end

      def bulk_create(opts)
        payload = { :docs => opts.map do |params|
          params       = params.clone
          params[:_id] = params.delete(:id) || Divan::Utils.uuid)
          params
        end.to_json
        last_request = database.client['_bulk_docs'].post( payload, :content_type => :json, :accept => :json )
      end
    end
  end
end
