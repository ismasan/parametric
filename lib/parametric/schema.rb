require 'ostruct'

module Parametric
  class Schema
    def initialize(&block)
      @fields = []
      self.instance_eval(&block) if block_given?
    end

    def schema
      fields.each_with_object({}) do |field, obj|
        meta = field.meta_data.dup
        sc = meta.delete(:schema)
        meta[:schema] = sc.schema if sc
        obj[field.key] = OpenStruct.new(meta)
      end
    end

    def field(key)
      f = key.kind_of?(Field) ? key : Field.new(key)
      fields << f
      f
    end

    def resolve(payload)
      context = Context.new
      output = coerce(payload, nil, context)
      Results.new(output, context.errors)
    end

    def exists?(*_)
      true
    end

    def valid?(*_)
      true
    end

    def coerce(val, _, context)
      fields.each_with_object({}) do |field, m|
        field.resolve(val, context.sub(field.key)) do |r|
          m[field.key] = r
        end
      end
    end

    protected
    attr_reader :fields
  end

end
