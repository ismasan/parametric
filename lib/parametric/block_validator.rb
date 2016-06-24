module Parametric
  class BlockValidator
    def self.build(meth, &block)
      klass = Class.new(self)
      klass.public_send(meth, &block)
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

    def self.exists(&block)
      @exists_block = block if block_given?
      @exists_block
    end

    attr_reader :message

    def initialize(*args)
      @args = args
      @message = 'is invalid'
      @validate_block = self.class.validate || ->(*args) { true }
      @coerce_block = self.class.coerce || ->(v, *_) { v }
      @exists_block = self.class.exists || ->(*args) { true }
    end

    def exists?(value, key, payload)
      args = (@args + [value, key, payload])
      @exists_block.call(*args)
    end

    def coerce(value, key, context)
      @coerce_block.call(value, key, context)
    end

    def valid?(value, key, payload)
      args = (@args + [value, key, payload])
      @message = self.class.message.call(*args) if self.class.message
      @validate_block.call(*args)
    end
  end
end
