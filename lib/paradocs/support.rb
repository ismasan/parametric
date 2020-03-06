require "delegate"

module Support
  module Tryable #:nodoc:
    def try(method_name = nil, *args, &b)
      if method_name.nil? && block_given?
        if b.arity == 0
          instance_eval(&b)
        else
          yield self
        end
      elsif respond_to?(method_name)
        public_send(method_name, *args, &b)
      end
    end

    def try!(method_name = nil, *args, &b)
      if method_name.nil? && block_given?
        if b.arity == 0
          instance_eval(&b)
        else
          yield self
        end
      else
        public_send(method_name, *args, &b)
      end
    end
  end
end

class Object
  include Support::Tryable
end

class Delegator
  include Support::Tryable
end

class NilClass
  def try(_method_name = nil, *, **)
    nil
  end

  def try!(_method_name = nil, *, **)
    nil
  end
end
