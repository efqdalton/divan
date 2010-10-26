module Divan
  module Models
    class Revision < Models::Base
      attr_reader :revisioned_doc, :revisioned_at, :revisioned_by

      def initialize(*args)
        super
        @revisioned_doc = @meta_attributes.delete :revision_of
        @revisioned_at  = @meta_attributes.delete :revisioned_at
        @revisioned_by  = @meta_attributes.delete :revisioned_by
      end

      def rollback
        revisioned_doc.attributes = @attributes.clone
        revisioned_doc.save :last_wins
      end

      class << self
        attr_reader :revisioned_class

        def create_by_revisioned_doc(rev_doc, rev_by = nil)
          self.new rev_doc.params
          self.id         = URI.encode "_revision/#{rev_doc.rev}"
          @revisioned_doc = rev_doc
          # parsed_time     = Date._parse rev_doc.last_request.headers[:date]
          # @revisioned_at  = Time.gm *[:year, :mon, :mday, :hour, :min, :sec].collect{ |k| parsed_time[k] }
          @revisioned_at  = Divan::Utils.parse_time rev_doc.last_request.headers[:date]
          @revisioned_by  = rev_by
          self.save
        end

        def revisioned_class=(rev_class)
          @revisioned_class = rev_class
          self.database     = rev_class.database
          self.model_name   = rev_class.model_name + '_revision'
        end
        alias :revision_of :'revisioned_class='

        def type_name
          revisioned_class.type_name
        end

        def type_field
          revisioned_class.type_field
        end

        def top_level_model!(*args)
          raise "Can't modify revision top level"
        end

        def top_level_model?
          revisioned_class.top_level_model?
        end

        def inherithed(subclass)
          nil
        end
      end

    end
  end
end