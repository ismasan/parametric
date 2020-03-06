require "paradocs"

module Paradocs
  module DSL
    # Example
    #   class Foo
    #     include Paradocs::DSL
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
    DEFAULT_SCHEMA_NAME = :schema

    def self.included(base)
      base.extend(ClassMethods)
      base.schemas = {DEFAULT_SCHEMA_NAME => Paradocs::Schema.new}
    end

    module ClassMethods
      def schema=(sc)
        @schemas[DEFAULT_SCHEMA_NAME] = sc
      end

      def schemas=(sc)
        @schemas = sc
      end

      def inherited(subclass)
        subclass.schemas = @schemas.each_with_object({}) do |(key, sc), hash|
          hash[key] = sc.merge(Paradocs::Schema.new)
        end
      end

      def schema(*args, &block)
        options = args.last.is_a?(Hash) ? args.last : {}
        key = args.first.is_a?(Symbol) ? args.first : DEFAULT_SCHEMA_NAME
        current_schema = @schemas.fetch(key) { Paradocs::Schema.new }
        new_schema = if block_given? || options.any?
          Paradocs::Schema.new(options, &block)
        elsif args.first.respond_to?(:schema)
          args.first
        end

        return current_schema unless new_schema

        @schemas[key] = current_schema ? current_schema.merge(new_schema) : new_schema
        paradocs_after_define_schema(@schemas[key])
        @schemas[key]
      end

      def subschema_for(main_schema, name:, **kwargs, &block)
        subschema = schema(name, kwargs, &block)
        @schemas[main_schema].subschemes[name] = subschema
        subschema
      end

      def paradocs_after_define_schema(sc)
        # noop hook
      end
    end
  end
end
