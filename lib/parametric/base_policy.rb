module Parametric
  class BasePolicy
    def self.build(name, meth, &block)
      klass = Class.new(self)
      klass.public_send(meth, &block)
      klass.policy_name = name
      klass
    end

    def self.message(&block)
      @message_block = block if block_given?
      @message_block
    end

    def self.validate(&validate_block)
      @validate_block = validate_block if block_given?
      @validate_block
    end

    def self.coerce(&coerce_block)
      @coerce_block = coerce_block if block_given?
      @coerce_block
    end

    def self.eligible(&block)
      @eligible_block = block if block_given?
      @eligible_block
    end

    def self.meta_data(&block)
      @meta_data_block = block if block_given?
      @meta_data_block
    end

    %w(error silent_error).each do |name|
      getter = "#{name}s"
      define_singleton_method(getter) { instance_variable_get("@#{getter}") || instance_variable_set("@#{getter}", []) }

      define_singleton_method("register_#{name}") do |*exceptions|
        instance_variable_set("@#{getter}", ((self.public_send(getter) || []) + exceptions).uniq)
      end

      define_method(getter) do
        instance_variable_set("@#{getter}", self.class.send("register_#{name}") || [])
      end
    end

    def self.policy_name=(name)
      @policy_name = name
    end

    def self.policy_name
      @policy_name
    end

    attr_accessor :environment
    def initialize(*args)
      @init_params = args
    end

    def eligible?(value, key, payload)
      args = (init_params + [value, key, payload])
      (self.class.eligible || ->(*) { true }).call(*args)
    end

    def coerce(value, key, context)
      (self.class.coerce || ->(v, *_) { v }).call(value, key, context)
    end

    def valid?(value, key, payload)
      args = (init_params + [value, key, payload])
      @message = self.class.message.call(*args) if self.class.message
      validate(*args)
    end

    def meta_data
      meta.merge((self.class.meta_data || -> (*) { {} }).call(*init_params))
    end

    def validate(*args)
      (self.class.validate || ->(*) { true }).call(*args)
    end

    def policy_name
      (self.class.policy_name || self.to_s.demodulize.underscore).to_sym
    end

    def message
      @message ||= 'is invalid'
    end

    protected

    def validate(*args)
      (self.class.validate || ->(*args) { true }).call(*args)
    end

    private

    def meta #maybe call this guy instead of meta_data
      @meta = errors.empty? ? {} : {self.class.policy_name => {errors: self.class.errors}}
    end

    def init_params
      @init_params ||= [] # safe default if #initialize was overwritten
    end
  end
end
