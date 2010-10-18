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

    def validate
      true
    end
    alias :"valid?" :validate 

    def database
      self.class.database
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

    class << self
      attr_writer :database, :name
      attr_reader :view_by_params

      def properties
        @properties ||= []
      end

      def property(*args)
        unless @properties
          begin
            @properties = ( superclass.properties.nil? ) ? [] : superclass.properties
          rescue NoMethodError
            @properties = []
          end
        end
        @properties.concat args.flatten!
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

    end
  end
end
