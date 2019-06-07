# Order of methods calls: (when a policy is applied to a field)
# 1).policy_name: is used to register the policy, thus it's called first
# 2) .initialize: is called when a policy is called, it can take optional arguments that might be used in further
# 3) #eligible?: is called right after constructor, it decides whether to proceed with validation or not
# 4) #coerce: if #eligible? returned true given value will be transformed to the one you specify inside this method
# 5) #valid?: should return boolean or call #raise_error
class Parametric::BasePolicy
  attr_accessor :environment
  # Enrich this object with {name: error_class} in your policy class and use #raise_error method
  # It is used for documentation generation and is a single resource for defining available errors
  # of your policy. If ERRORS in your policy class is empty then policy name will be without bang!
  # otherwise a bang will be added to the end, as a notice that policy raises exception
  ERRORS = {}

  # Overwrite this method to specify the error message for your policy if validation doesn't pass.
  # Note that if your policy raises error this method won't be called.
  # Also note that this method doesn't accept arguments, if you need them then ensure you've #save_env
  # method somewhere before
  def message
    "value for #{key} is invalid"
  end

  # Overwrite this method to add your custom validation logic for a policy.
  def valid?(*)
    true
  end

  # Overwrite this method to change the field's value before validation is called
  def coerce(value, _, _)
    value
  end

  # TODO: merge with meta_data
  def for_docs
    {_errors: self.class::ERRORS}
  end

  # Overwrite this method to identify whether to proceed with validation(#valid?) or not
  def eligible?(value, key, context)
    save_env(value, key, context)
    context.try(:key?, key)
  end

  # WARNING: If you overwrite this method in your subclass ensure the data below is specified
  def meta_data
    {name: self.class.policy_name}
  end

  # This method is needed to save given data into the instance attributes to allow them
  # be used in your overwritten #message method. Ensure you used it in one of the following methods:
  # #eligible?, #coerce, #valid? to not
  attr_reader :value, :key, :context
  def save_env(value, key, context)
    @value, @key, @context = value, key, context
  end

  # Use this method to raise errors if you want
  def raise_error(key, *attributes)
    raise self.class::ERRORS[key].new(*attributes)
  end

  # Overwrite this method to change your policy' name
  def self.policy_name
    name = self.to_s.demodulize.underscore
    (self::ERRORS.empty? ? name : "#{name}!").to_sym
  end

  # WARNING: Don't overwrite this method! It's used to run another policy from policy
  def self.run_policy(name, init_params=[], *args)
    policy = Parametric.registry.policies[name].new(*init_params)
    arguments = Array.new(3) { args.shift }
    arguments = [policy.coerce(*arguments)] + arguments.slice(1..2)
    policy.valid?(*arguments)
  end

  def self.is_custom?
    true
  end
end
