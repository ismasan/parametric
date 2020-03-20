module Paradocs
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
    attr_reader :environment
    def initialize(path=nil, top=Top.new, environment={}, subschemes={})
      @top = top
      @path = Array(path).compact
      @environment = environment
      @subschemes = subschemes
    end

    def subschema(subschema_name)
      subschema = @subschemes[subschema_name]
      return unless subschema
      @subschemes.merge!(subschema.subschemes)
      subschema
    end

    def errors
      top.errors
    end

    def add_error(msg)
      top.add_error(string_path, msg)
    end

    def sub(key)
      self.class.new(path + [key], top, environment, @subschemes)
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
