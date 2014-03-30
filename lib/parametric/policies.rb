module Parametric
  module Policies

    class Policy
      def initialize(value, options, decorated = nil)
        @value, @options = value, options
        @decorated = decorated
      end

      def wrap(decoratedClass)
        decoratedClass.new(@value, @options, self)
      end

      def value
        [@value].flatten
      end

      protected
      attr_reader :decorated, :options
    end

    class DefaultPolicy < Policy
      def value
        v = decorated.value
        v.any? ? v : Array(options[:default])
      end
    end

    class MultiplePolicy < Policy
      OPTION_SEPARATOR = /\s*,\s*/.freeze

      def value
        decorated.value.map do |v|
          v.is_a?(String) ? v.split(options.fetch(:separator, OPTION_SEPARATOR)) : v
        end.flatten
      end
    end

    class NestedPolicy < Policy
      def value
        decorated.value.map do |v|
          options[:nested].new(v)
        end
      end
    end

    class CoercePolicy < Policy
      def value
        decorated.value.map do |v|
          v.respond_to?(options[:coerce]) ? v.send(options[:coerce]) : v
        end
      end
    end

    class SinglePolicy < Policy
      def value
        decorated.value.first
      end
    end

    class OptionsPolicy < Policy
      def value
        decorated.value.each_with_object([]){|a,arr| 
          arr << a if options[:options].include?(a)
        }
      end
    end

    class MatchPolicy < Policy
      def value
        decorated.value.each_with_object([]){|a,arr| 
          arr << a if a.to_s =~ options[:match]
        }
      end
    end

  end
end