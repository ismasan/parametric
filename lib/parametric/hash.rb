module Parametric
  module Hash

    def self.included(base)
      base.send(:include, Params)
      base.send(:include, Enumerable)
      base.extend Forwardable
      base.send(:def_delegators, :params,
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
        :store
      )
    end

  end
end