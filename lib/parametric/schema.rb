require "parametric/context"
require "parametric/results"
require "parametric/field"

module Parametric
  class Schema
    attr_accessor :environment, :subschemes, :subschemes_identifiers
    def initialize(options = {}, &block)
      @options = options
      @fields = {}
      @subschemes = {}
      @subschemes_identifiers = {}
      @definitions = []
      @definitions << block if block_given?
      @default_field_policies = []
      @ignored_field_keys = []
      @expansions = {}
    end

    def schema
      self
    end

    def fields
      apply!
      @fields
    end

    def policy(*names, &block)
      @default_field_policies = names
      definitions << block if block_given?

      self
    end

    def ignore(*field_keys, &block)
      @ignored_field_keys += field_keys
      @ignored_field_keys.uniq!

      definitions << block if block_given?

      self
    end

    def clone
      instance = self.class.new(options)
      copy_into instance
    end

    def merge(other_schema)
      instance = self.class.new(options.merge(other_schema.options))

      copy_into(instance)
      other_schema.copy_into(instance)
    end

    def copy_into(instance)
      instance.policy(*default_field_policies) if default_field_policies.any?

      definitions.each do |d|
        instance.definitions << d
      end

      instance.ignore *ignored_field_keys
      instance
    end

    def structure
      fields.each_with_object({}) do |(_, field), obj|
        meta = field.meta_data.dup
        sc = meta.delete(:schema)
        meta[:structure] = sc.structure if sc
        obj[field.key] = meta
      end
    end

    def field(field_or_key)
      f, key = if field_or_key.kind_of?(Field)
        [field_or_key, field_or_key.key]
      else
        [Field.new(field_or_key), field_or_key.to_sym]
      end

      if ignored_field_keys.include?(f.key)
        f
      else
        @fields[key] = apply_default_field_policies_to(f)
      end
    end

    def subschema_by(*keys, &block)
      @subschemes_identifiers[keys] = block
    end

    def expand(exp, &block)
      expansions[exp] = block
      self
    end

    def resolve(payload, environment={})
      @environment = environment
      context = Context.new(nil, Top.new, @environment, @subschemes)
      output = coerce(payload, nil, context)
      Results.new(output, context.errors)
    end

    def walk(meta_key = nil, &visitor)
      r = visit(meta_key, &visitor)
      Results.new(r, {})
    end

    def eligible?(value, key, payload)
      payload.key? key
    end

    def valid?(*_)
      true
    end

    def meta_data
      {}
    end

    def visit(meta_key = nil, &visitor)
      fields.each_with_object({}) do |(_, field), m|
        m[field.key] = field.visit(meta_key, &visitor)
      end
    end

    def coerce(val, _, context)
      if val.is_a?(Array)
        val.map.with_index do |v, idx|
          subcontext = context.sub(idx)
          out = coerce_one(v, subcontext)
          resolve_expansions(v, out, subcontext)
        end
      else
        out = coerce_one(val, context)
        resolve_expansions(val, out, context)
      end
    end

    def schema_with_subschemes(val, context)
      apply!
      instance = self.clone
      @subschemes_identifiers.each do |dependencies, subschema|
        new_schema_name = subschema.call(*val.values_at(*dependencies))
        next unless new_schema_name
        new_schema = new_schema_name.is_a?(Schema) ? new_schema_name : context.subschemes[new_schema_name]
        context = context.subschema_reduce!(new_schema_name)
        new_schema&.copy_into instance
      end
      [instance, context]
    end

    protected

    attr_reader :definitions, :options

    private

    attr_reader :default_field_policies, :ignored_field_keys, :expansions

    def coerce_one(val, context, flds: nil)
      new_schema, context = schema_with_subschemes(val, context)
      flds ||= new_schema.fields
      flds.each_with_object({}) do |(_, field), m|
        r = field.resolve(val, context.sub(field.key))
        if r.eligible?
          m[field.key] = r.value
        end
      end
    end

    class MatchContext
      def field(key)
        Field.new(key.to_sym)
      end
    end

    def resolve_expansions(payload, into, context)
      expansions.each do |exp, block|
        payload.each do |key, value|
          if match = exp.match(key.to_s)
            fld = MatchContext.new.instance_exec(match, &block)
            if fld
              into.update(coerce_one({fld.key => value}, context, flds: {fld.key => apply_default_field_policies_to(fld)}))
            end
          end
        end
      end

      into
    end

    def apply_default_field_policies_to(field)
      default_field_policies.reduce(field) {|f, policy_name| f.policy(policy_name) }
    end

    def apply!
      return if @applied
      definitions.each do |d|
        self.instance_exec(options, &d)
      end
      @applied = true
    end
  end
end
