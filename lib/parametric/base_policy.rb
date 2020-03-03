# Order of methods calls: (when a policy is applied to a field)
# 1).policy_name: is used to register the policy, thus it's called first
# 2) .initialize: is called when a policy is called, it can take optional arguments that might be used in further
# 3) #eligible?: is called right after constructor, it decides whether to proceed with validation or not
# 4) #coerce: if #eligible? returned true given value will be transformed to the one you specify inside this method
# 5) #valid?: should return boolean or call #raise_error
class Parametric::BasePolicy < Parametric::BlockValidator
  attr_accessor :environment

  # Overwrite this method to change your policy' name
  def self.policy_name # NOTE: move it out
    name = self.to_s.demodulize.underscore
    (self.errors.empty? ? name : "#{name}!").to_sym
  end

  # WARNING: Don't overwrite this method! It's used to run another policy from policy
  def self.run_policy(name, init_params=[], *args)
    policy = Parametric.registry.policies[name].new(*init_params)
    arguments = Array.new(3) { args.shift }
    arguments = [policy.coerce(*arguments)] + arguments.slice(1..2)
    policy.valid?(*arguments)
  end
end
