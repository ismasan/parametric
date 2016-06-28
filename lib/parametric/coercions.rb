module Parametric
  # other coercions
  Parametric.coercion :split, ->(v, k, c){
    v.kind_of?(Array) ? v : v.to_s.split(/\s*,\s*/)
  }
end
