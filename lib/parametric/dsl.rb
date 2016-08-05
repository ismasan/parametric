require "parametric/schema"

module Parametric
  module DSL
    # Example
    #   class Foo
    #     include Parametric::DSL
    #
    #     schema do
    #       field(:title).type(:string).present
    #       field(:age).type(:integer).default(20)
    #     end
    #
    #      attr_reader :params
    #
    #      def initialize(input)
    #        @params = self.class.schema.resolve(input)
    #      end
    #   end
    #
    #   foo = Foo.new(title: "A title", nope: "hello")
    #
    #   foo.params # => {title: "A title", age: 20}
    #
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def schema=(sc)
        @schema = sc
      end

      def inherited(subclass)
        parent_schema = self.schema || Parametric::Schema.new
        subclass.schema = parent_schema.dup
      end

      def schema(options = {}, &block)
        if block_given? # defining schema
          new_schema = Parametric::Schema.new(options, &block)
          @schema = if @schema
            @schema.merge(new_schema)
          else
            new_schema
          end
        end

        @schema
      end
    end
  end
end
