module Parametric
  class BlockValidator
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
        instance_variable_set("@#{getter}",
                              ((self.public_send(getter) || []) + exceptions).uniq)
      end
    end

    def self.policy_name=(name)
      @policy_name = name
    end

    def self.policy_name
      @policy_name
    end

    attr_reader :errors, :silent_errors, :value, :key
    attr_accessor :environment

    def initialize(*args)
      @init_params = args
      @errors = self.class.register_error || []
      @silent_errors = self.class.register_silent_error || []
    end

    def eligible?(value, key, payload)
      args = (init_params + [value, key, payload])
      (self.class.eligible || ->(*) { true }).call(*args)
    end

    def coerce(value, key, context)
      (self.class.coerce || ->(v, *_) { v }).call(value, key, context)
    end

    def valid?(value, key, payload) # Do not overwrite this method unless you know what to do. Overwrite #validate instead
      args = (init_params + [value, key, payload])
      @message = self.class.message.call(*args) if self.class.message
      validate(*args)
    end

    def meta_data
      (self.class.meta_data || ->(*) { {name: self.class.policy_name} }).call(*init_params)
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

    def validate(*args) # This method is free to overwrite
      (self.class.validate || ->(*args) { true }).call(*args)
    end

private

    def init_params
      @init_params ||= [] # safe default if #initialize was overwritten
    end
  end
end
