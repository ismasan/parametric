module Parametric
  class Top
    attr_reader :errors

    def initialize
      @errors = {}
    end

    def add_error(key, msg)
      errors[key] ||= []
      errors[key] << msg
    end
  end

  class Context
    attr_reader :environment, :subschemes
    def initialize(path=nil, top=Top.new, environment={}, subschemes={})
      @top = top
      @path = Array(path).compact
      @environment = environment
      @subschemes = subschemes
    end

    def subschema_reduce!(subschema_name)
      reduced = @subschemes.clone
      subschema = reduced.delete(subschema_name)
      return self unless subschema
      reduced.merge!(subschema.subschemes)
      self.class.new(@path, @top, @environment, reduced)
    end

    def errors
      top.errors
    end

    def add_error(msg)
      top.add_error(string_path, msg)
    end

    def sub(key)
      self.class.new(path + [key], top, environment, subschemes)
    end

    protected
    attr_reader :path, :top

    def string_path
      path.reduce(['$']) do |m, segment|
        m << (segment.is_a?(Integer) ? "[#{segment}]" : ".#{segment}")
        m
      end.join
    end
  end

end
