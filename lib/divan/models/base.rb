module Divan
  module Models
    class Base

      def save(strategy=nil, &block)
        self.class.execute_before_validate_callback(self) or return false

        validate or return false

        self.class.execute_after_validate_callback(self)  or return false
        self.class.execute_before_save_callback(self)     or return false

        execute_save strategy, &block

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

      def revision_ids
        begin
          @last_request = database.client[document_path :revs_info => true].get
          JSON.parse(@last_request, :symbolize_names => true )[:_revs_info].find_all{ |hash| hash[:status] == 'available' }.map{ |hash| hash[:rev] }
        rescue RestClient::ResourceNotFound
          return []
        end
      end

      def revision(index)
        revision!(index)
      rescue Divan::Divan::DocumentRevisionNotAvailable
        nil
      end

      def revision!(index)
        r = revision_ids.find{ |rev| rev[0..1].to_i == index}
        r.nil? and raise Divan::Divan::DocumentRevisionNotAvailable.new(self), "Revision with index #{index} missing"
        return self if r == @rev
        self.class.find @id, :rev => r
      end

      protected

      def execute_save(strategy=nil, &block)
        previous_request = @last_request
        begin
          save_attrs = @attributes.clone
          save_attrs[:"_rev"] = @rev if @rev
          save_attrs.delete(:id)
          save_attrs.delete(:_id)
          @last_request = database.client[current_document_path].put save_attrs.to_json
          @rev = JSON.parse(@last_request, :symbolize_names => true )[:rev]
        rescue RestClient::Conflict
          if methods.include?("#{strategy}_strategy")
            run_strategy_in_function strategy
          elsif block_given?
            run_strategy_in_block &block 
          else
            raise Divan::DocumentConflict.new(self), "Update race conflict"
          end
        end
      end

      def run_strategy_in_function(strategy)
        conflict_doc = self.class.find(id)
        @rev         = conflict_doc.rev
        if send( "#{strategy}_strategy", self.class.find(id) )
          execute_save strategy
        else
          @attributes   = conflict_doc.attributes
          @last_request = conflict_doc.last_request
        end
      end

      def run_strategy_in_block(&block)
        conflict_doc = self.class.find(id)
        @rev = conflict_doc.rev
        if yield(self, conflict_doc)
          self.execute_save(nil, &block)
        else
          @attributes   = conflict_doc.attributes
          @last_request = conflict_doc.last_request
        end
      end

      def first_wins_strategy(current_document)
        return false
      end

      def last_wins_strategy(current_document)
        return true
      end

      def merge_strategy(current_document)
        @attributes = current_document.attributes.merge @attributes
      end

      class << self
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

        def create(opts = {})
          raise ArgumentError if( !opts.is_a?(Hash) && !opts.is_a?(Array) )
          if opts.is_a? Hash
            single_create opts
          else
            bulk_create opts
          end
        end

        protected

        def single_create(opts = {})
          obj = self.new(opts)
          obj.save
          obj
        end

        def bulk_create(opts)
          payload = { :docs => opts.map do |params|
            params       = params.clone
            params[:_id] = params.delete(:id) || Divan::Utils.uuid
            params[type_field.to_sym] = type_name unless top_level_model?
            params
          end }
          last_request = database.client['_bulk_docs'].post( payload.to_json, :content_type => :json, :accept => :json )
        end

      end

    end
  end
end