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
    attr_reader :global_dependencies
    def initialize(path = nil, top = Top.new, global_dependencies = {})
      @top = top
      @path = Array(path).compact
      @global_dependencies = global_dependencies
    end

    def errors
      top.errors
    end

    def add_error(msg)
      top.add_error(string_path, msg)
    end

    def sub(key)
      self.class.new(path + [key], top, global_dependencies)
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
