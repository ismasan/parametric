# frozen_string_literal: true

require 'spec_helper'
require 'parametric/v2/type_registry'

class Steppable
end

module Tests
  module TestRegistry
    extend Parametric::V2::TypeRegistry

    Foo = Steppable.new
    Bar = Steppable.new

    module Child
      Bar = Steppable.new
    end
  end

  module Host
    include TestRegistry

    MyString = Steppable.new

    module Child
      MyBar = Steppable.new
    end
  end

  module Host2
    include Host
  end
end

RSpec.describe Parametric::V2::TypeRegistry do
  specify '.extend' do
    expect(Tests::TestRegistry::Foo.inspect).to eq('Tests::TestRegistry::Foo')
    expect(Tests::TestRegistry::Bar.inspect).to eq('Tests::TestRegistry::Bar')
    expect(Tests::TestRegistry::Child::Bar.inspect).to eq('Tests::TestRegistry::Child::Bar')
  end

  specify '.include' do
    expect(Tests::Host::Foo.inspect).to eq('Tests::Host::Foo')
    expect(Tests::Host::Foo.object_id).not_to eq(Tests::TestRegistry::Foo.object_id)
    expect(Tests::Host::Child::Bar.inspect).to eq('Tests::Host::Child::Bar')
    expect(Tests::Host::Child::MyBar.inspect).to eq('Tests::Host::Child::MyBar')
    expect(Tests::Host::MyString.inspect).to eq('Tests::Host::MyString')
    expect(Tests::Host2::MyString.inspect).to eq('Tests::Host2::MyString')
    expect(Tests::Host2::MyString.object_id).not_to eq(Tests::Host::MyString.object_id)
  end
end
