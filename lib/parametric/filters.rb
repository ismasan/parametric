module Parametric
  # other filters
  Parametric.filter :split, ->(v, k, c){
    v.kind_of?(Array) ? v : v.to_s.split(/\s*,\s*/)
  }
end
