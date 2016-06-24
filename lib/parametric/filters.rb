module Parametric
  # type coercions
  Parametric.filter :integer, ->(v, k, c){ v.to_i }
  Parametric.filter :number, ->(v, k, c){ v.to_f }
  Parametric.filter :string, ->(v, k, c){ v.to_s }
  Parametric.filter :boolean, ->(v, k, c){ !!v }
  Parametric.filter :object, ->(v, k, c){ v }

  # other filters
  Parametric.filter :split, ->(v, k, c){ v.kind_of?(Array) ? v : v.to_s.split(/\s*,\s*/) }

  Parametric.validator :array do
    message do |actual|
      "expects an array, but got #{actual.inspect}"
    end

    validate do |value, key, payload|
      !payload.key?(key) || value.is_a?(Array)
    end
  end
end
