require 'ostruct'

module Parametric
  class Schema
    attr_reader :fields, :definitions, :options

    def initialize(options = {}, &block)
      @options = options
      @fields = {}
      @definitions = block
      apply(block, @options) if block_given?
    end

    def merge(other_schema)
      instance = self.class.new

      instance.apply(definitions, other_schema.options)
      instance.apply(other_schema.definitions, other_schema.options)

      instance
    end

    def schema
      fields.each_with_object({}) do |(_, field), obj|
        meta = field.meta_data.dup
        sc = meta.delete(:schema)
        meta[:schema] = sc.schema if sc
        obj[field.key] = OpenStruct.new(meta)
      end
    end

    def field(key)
      if key.kind_of?(Field)
        fields[key.key] = key
        key
      else
        f = Field.new(key)
        fields[key.to_sym] = f
        f
      end
    end

    def resolve(payload)
      context = Context.new
      output = coerce(payload, nil, context)
      Results.new(output, context.errors)
    end

    def walk(meta_key = nil, &visitor)
      r = visit(meta_key, &visitor)
      Results.new(r, {})
    end

    def exists?(*_)
      true
    end

    def valid?(*_)
      true
    end

    def visit(meta_key = nil, &visitor)
      fields.each_with_object({}) do |(_, field), m|
        m[field.key] = field.visit(meta_key, &visitor)
      end
    end

    def coerce(val, _, context)
      if val.is_a?(Array)
        val.map.with_index{|v, idx|
          coerce_one(v, context.sub(idx))
        }
      else
        coerce_one val, context
      end
    end

    def apply(block, opts = {})
      self.instance_exec(opts, &block) if block
      self
    end

    private

    def coerce_one(val, context)
      fields.each_with_object({}) do |(_, field), m|
        r = field.resolve(val, context.sub(field.key))
        if r.eligible?
          m[field.key] = r.value
        end
      end
    end
  end
end
