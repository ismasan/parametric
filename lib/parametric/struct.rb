require 'parametric'

module Parametric
  module Struct
    def self.included(base)
      base.extend ClassMethods
      base.schema = Parametric::Schema.new
    end

    def initialize(attrs = {})
      @_results = self.class.schema.resolve(attrs)
      @_graph = build(@_results.output)
    end

    def valid?
      !_results.errors.any?
    end

    def errors
      _results.errors
    end

    def to_h
      _results.output
    end

    private
    attr_reader :_graph, :_results

    def build(attrs)
      attrs.each_with_object({}) do |(k, v), obj|
        obj[k] = wrap(k, v)
      end
    end

    def wrap(key, value)
      field = self.class.schema.fields[key]
      return value unless field

      case value
      when Hash
        # find constructor for field
        cons = field.meta_data[:schema]
        if cons.kind_of?(Parametric::Schema)
          klass = Class.new do
            include Struct
          end
          klass.schema = cons
          klass.setup
          cons = klass
        end
        cons ? cons.new(value) : value.freeze
      when Array
        value.map{|v| wrap(key, v) }.freeze
      else
        value.freeze
      end
    end

    module ClassMethods
      def schema=(sc)
        @schema = sc
      end

      def inherited(subclass)
        subclass.schema = schema.merge(Parametric::Schema.new)
      end

      def schema(options = {}, &block)
        return @schema unless options.any? || block_given?
        new_schema = Parametric::Schema.new(options, &block)
        @schema = @schema.merge(new_schema)
        setup
      end

      def setup
        schema.fields.keys.each do |key|
          define_method key do
            _graph[key]
          end
        end
      end
    end
  end
end
