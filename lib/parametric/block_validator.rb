module Parametric
  class BlockValidator
    def self.build(meth, &block)
      klass = Class.new(self)
      klass.public_send(meth, &block)
      klass
    end

    def self.message(&block)
      @message_block = block if block_given?
      @message_block if instance_variable_defined?('@message_block')
    end

    def self.validate(&validate_block)
      @validate_block = validate_block if block_given?
      @validate_block if instance_variable_defined?('@validate_block')
    end

    def self.coerce(&coerce_block)
      @coerce_block = coerce_block if block_given?
      @coerce_block
    end

    def self.eligible(&block)
      @eligible_block = block if block_given?
      @eligible_block if instance_variable_defined?('@eligible_block')
    end

    def self.meta_data(&block)
      @meta_data_block = block if block_given?
      @meta_data_block if instance_variable_defined?('@meta_data_block')
    end

    attr_reader :message

    def initialize(*args)
      @args = args
      @message = 'is invalid'
      @validate_block = self.class.validate || ->(*args) { true }
      @coerce_block = self.class.coerce || ->(v, *_) { v }
      @eligible_block = self.class.eligible || ->(*args) { true }
      @meta_data_block = self.class.meta_data || ->(*args) { {} }
    end

    def eligible?(value, key, payload)
      args = (@args + [value, key, payload])
      @eligible_block.call(*args)
    end

    def coerce(value, key, context)
      @coerce_block.call(value, key, context)
    end

    def valid?(value, key, payload)
      args = (@args + [value, key, payload])
      @message = self.class.message.call(*args) if self.class.message
      @validate_block.call(*args)
    end

    def meta_data
      @meta_data_block.call *@args
    end
  end
end
