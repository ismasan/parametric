require 'parametric/dsl'

module Parametric
  module Struct
    def self.included(base)
      base.send(:include, Parametric::DSL)
      base.extend ClassMethods
    end

    def initialize(attrs = {})
      @_results = self.class.schema.resolve(attrs)
      @_graph = self.class.build(@_results.output)
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

    module ClassMethods
      # this hook is called after schema definition in DSL module
      def after_define_schema(schema)
        schema.fields.keys.each do |key|
          define_method key do
            _graph[key]
          end
        end
      end

      def build(attrs)
        attrs.each_with_object({}) do |(k, v), obj|
          obj[k] = wrap(k, v)
        end
      end

      def wrap(key, value)
        field = schema.fields[key]
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
            klass.after_define_schema(cons)
            cons = klass
          end
          cons ? cons.new(value) : value.freeze
        when Array
          value.map{|v| wrap(key, v) }.freeze
        else
          value.freeze
        end
      end
    end
  end
end
