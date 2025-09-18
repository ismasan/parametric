# frozen_string_literal: true

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

    def [](key)
      _results.output[key.to_sym]
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
            case field.meta_data[:schema]
            when Parametric::Schema
              klass = Class.new do
                include Struct
              end
              klass.schema = field.meta_data[:schema]
              self.const_set(__class_name(field.key), klass)
              klass.parametric_after_define_schema(field.meta_data[:schema])
            when Array
              # Handle one_of fields: create multiple struct classes, one for each possible schema
              # This allows the field to instantiate the appropriate nested struct based on which schema validates
              classes = field.meta_data[:schema].map.with_index(1) do |sc, idx|
                klass = Class.new do
                  include Struct
                end
                klass.schema = sc
                class_name = "#{__class_name(field.key)}#{idx}"
                self.const_set(__class_name(class_name), klass)
                klass.parametric_after_define_schema(sc)
                klass
              end
              self.const_set(__class_name(field.key), classes)
            else
              self.const_set(__class_name(field.key), field.meta_data[:schema])
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
          cons = self.const_get(__class_name(key))
          case cons
          when Class # Single nested struct
            cons.new(value)
          when Array # Array of possible nested structs (one_of)
            # For one_of fields: instantiate all possible struct classes and return the first valid one
            # This allows the struct to automatically choose the correct nested structure based on the data
            structs = cons.map{|c| c.new(value) }
            structs.find(&:valid?) || structs.first
          else
            value.freeze
          end
        when Array
          value.map{|v| wrap(key, v) }.freeze
        else
          value.freeze
        end
      end

      PLURAL_END = /s$/.freeze

      def __class_name(key)
        key.to_s.split('_').map(&:capitalize).join.sub(PLURAL_END, '')
      end
    end
  end
end
