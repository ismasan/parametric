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
        cons = field.meta_data[:_of]
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

      def schema
        @schema ||= Parametric::Schema.new
      end

      def inherited(subclass)
        subclass.schema = schema.merge(Parametric::Schema.new)
      end

      def property(key, type = nil, of: nil, &block)
        default = case type
                  when :array
                    []
                  when :object
                    {}
                  else
                    nil
                  end

        define_method key do
          _graph[key]
        end

        if block_given?
          of = Class.new do
            include Parametric::Struct
            instance_exec &block
          end
        end

        schema.field(key).meta(_of: of).tap do |f|
          f.type(type) if type
          f.schema(of.schema) if of
          f.default(default) if default
        end
      end
    end
  end
end
