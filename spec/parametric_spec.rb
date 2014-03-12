require 'spec_helper'

describe Parametric do
  it 'should have a version number' do
    Parametric::VERSION.should_not be_nil
  end

  describe Parametric do

    let(:klass) do
      Class.new do
        include Parametric
        param :name, 'name'
        param :page, 'page number', default: 1
        param :per_page, 'items per page', default: 50
        param :status, 'status', options: ['one', 'two', 'three'], multiple: true
        param :piped_status, 'status with pipes', multiple: true, separator: '|'
        param :country, 'country', options: ['UK', 'CL', 'JPN']
        param :email, 'email', match: /\w+@\w+\.\w+/
        param :emails, 'emails', match: /\w+@\w+\.\w+/, multiple: true, default: 'default@email.com'
      end
    end

    describe '#params' do
      let(:subject) { klass.new(foo: 'bar', per_page: 20, status: 'four') }

      it 'ignores undeclared fields' do
        subject.params.has_key?(:foo).should be_false
      end

      it 'sets passed values' do
        subject.params[:per_page].should == 20
      end

      it 'uses defaults if no value passed' do
        subject.params[:page].should == 1
      end

      it 'does not set value if outside of declared options' do
        subject.params[:status].should == []
      end

      it 'does not set value if it does not :match' do
        klass.new(email: 'my@email').params[:email].should be_nil
      end

      it 'does set value if it does :match' do
        klass.new(email: 'my@email.com').params[:email].should == 'my@email.com'
      end

      it 'only sets value for :multiple values that :match' do
        klass.new(emails: 'my@email,your,her@email.com').params[:emails].should == ['her@email.com']
      end

      it 'returns :default wrapped in array if :multiple' do
        klass.new().params[:emails].should == ['default@email.com']
      end

      it 'turns :multiple comma-separated values into arrays' do
        klass.new(status: 'one,three').params[:status].should == ['one', 'three']
      end

      it 'turns :multiple separated values with custom separator into arrays' do
        klass.new(piped_status: 'one|three').params[:piped_status].should == ['one', 'three']
      end

      it 'does not turn non-multiple comma-separated values into arrays' do
        klass.new(name: 'foo,bar').params[:name].should == 'foo,bar'
      end

      it 'filters out undeclared options' do
        klass.new(status: 'one,three,fourteen').params[:status].should == ['one', 'three']
      end

      it 'defaults empty multiple options to empty array' do
        klass.new().params[:status].should == []
      end

      it 'wraps single multiple options in array' do
        klass.new(status: 'one').params[:status].should == ['one']
      end

      it 'does not accept comma-separated values outside of options unless :multiple == true' do
        klass.new(country: 'UK,CL').params[:country].should be_nil
      end

      it 'does accept single option' do
        klass.new(country: 'UK').params[:country].should == 'UK'
      end

      it 'does not accept single option if not in declared options' do
        klass.new(country: 'USA').params[:country].should be_nil
      end
    end

  end
end
