require "parametric"

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
      base.schema = Parametric::Schema.new
    end

    module ClassMethods
      def schema=(sc)
        @schema = sc
      end

      def inherited(subclass)
        subclass.schema = @schema.merge(Parametric::Schema.new)
      end

      def schema(options = {}, &block)
        return @schema unless options.any? || block_given?

        new_schema = Parametric::Schema.new(options, &block)
        @schema = @schema.merge(new_schema)
        after_define_schema(@schema)
      end

      def after_define_schema(sc)
        # noop hook
      end
    end
  end
end
