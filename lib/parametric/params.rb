module Parametric
  module Params
    def self.included(base)
      base.extend DSL
    end

    attr_reader :params, :schema

    def initialize(payload)
      results = self.class.schema.resolve(payload)
      @params = results.output
      @schema = self.class.schema.schema
    end

    module DSL
      def schema
        @schema ||= Schema.new
      end

      def param(key, label, opts = {}, &block)
        f = Field.new(key).meta(label: label)
        f.default(opts[:default]) if opts[:default]
        f.type(opts[:type]) if opts[:type]
        f.required if opts[:required]
        f.validate(opts[:validate]) if opts[:validate]
        f.validate(:format, opts[:match]) if opts[:match]
        if opts[:coerce]
          f.filter(->(v, _, _){ opts[:coerce].call(v) })
        end
        if block_given?
          sub_schema = Class.new(SubParams, &block)
          f.schema sub_schema.schema
        end
        schema.field f
      end

    end
  end

  module TypedParams
    def self.included(base)
      base.send(:include, Params)
      base.extend(TypesDSL)
    end

    module TypesDSL
      def string(name, label, opts = {}, &block)
        param name, label, opts.merge(type: :string), &block
      end

      def integer(name, label, opts = {}, &block)
        param name, label, opts.merge(type: :integer), &block
      end

      def array(name, label, opts = {}, &block)
        param name, label, opts.merge(type: :array), &block
      end
    end
  end

  class SubParams
    include TypedParams
  end
end
