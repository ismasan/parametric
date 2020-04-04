require 'parametric/dsl'

module Parametric
  class InvalidStructError < ArgumentError
    attr_reader :errors
    def initialize(struct)
      @errors = struct.errors
      msg = @errors.map do |k, strings|
        "#{k} #{strings.join(', ')}"
      end.join('. ')
      super "#{struct.class} is not a valid struct: #{msg}"
    end
  end

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

    # returns a shallow copy.
    def to_h
      _results.output.clone
    end

    def ==(other)
      other.respond_to?(:to_h) && other.to_h.eql?(to_h)
    end

    def merge(attrs = {})
      self.class.new(to_h.merge(attrs))
    end

    private
    attr_reader :_graph, :_results

    module ClassMethods
      def new!(attrs = {})
        st = new(attrs)
        raise InvalidStructError.new(st) unless st.valid?
        st
      end

      # this hook is called after schema definition in DSL module
      def parametric_after_define_schema(schema)
        schema.fields.values.each do |field|
          if field.meta_data[:schema]
            if field.meta_data[:schema].is_a?(Parametric::Schema)
              klass = Class.new do
                include Struct
              end
              klass.schema = field.meta_data[:schema]
              self.const_set("Sub_#{field.key}", klass)
              klass.parametric_after_define_schema(field.meta_data[:schema])
            else
              self.const_set("Sub_#{field.key}", field.meta_data[:schema])
            end
          end
          self.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{field.key}
              _graph[:#{field.key}]
            end
          RUBY
        end
      end

      def build(attrs)
        attrs.each_with_object({}) do |(k, v), obj|
          obj[k] = wrap(k, v)
        end
      end

      def wrap(key, value)
        case value
        when Hash
          # find constructor for field
          cons = self.const_get("Sub_#{key}")
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
