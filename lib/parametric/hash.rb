require 'forwardable'
module Parametric
  class Hash
    include TypedParams
    include Enumerable
    extend ::Forwardable
    def_delegators(:params,
      :[],
      :[]=,
      :each,
      :each_value,
      :each_key,
      :each_pair,
      :keys,
      :values,
      :values_at,
      :fetch,
      :size,
      :to_hash,
      :merge,
      :merge!,
      :replace,
      :update,
      :has_key?,
      :key?,
      :key,
      :select,
      :select!,
      :delete,
      :store,
      :inspect,
      :stringify_keys,
      :symbolize_keys
    )

  end

end