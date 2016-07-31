require 'spec_helper'

module Beaker
  module Shared
    describe OptionsResolver do

      describe 'run_in_parallel?' do

        it 'returns true if :run_in_parallel in opts is true' do
          expect( subject.run_in_parallel?({:run_in_parallel => true}, nil, nil) ).to be === true
        end

        it 'returns false if :run_in_parallel in opts is false' do
          expect( subject.run_in_parallel?({:run_in_parallel => false}, nil, nil) ).to be === false
        end

        it 'returns false if :run_in_parallel in opts is an empty array' do
          expect( subject.run_in_parallel?({:run_in_parallel => []}, nil, nil) ).to be === false
        end

        it 'returns false if :run_in_parallel in opts is an empty array but a mode is specified in options' do
          expect( subject.run_in_parallel?({:run_in_parallel => []}, {:run_in_parallel => ['install']}, 'install') ).to be === false
        end

        it 'returns true if opts is nil but a matching mode is specified in options' do
          expect( subject.run_in_parallel?(nil, {:run_in_parallel => ['install']}, 'install') ).to be === true
        end

        it 'returns false if opts is nil and a non matching mode is specified in options' do
          expect( subject.run_in_parallel?(nil, {:run_in_parallel => ['configure']}, 'install') ).to be === false
        end

        it 'returns true if opts is nil and a matching mode and a non matching mode is specified in options' do
          expect( subject.run_in_parallel?(nil, {:run_in_parallel => ['configure', 'install']}, 'install') ).to be === true
        end

        it 'returns false if opts is nil and no mode is specified in options' do
          expect( subject.run_in_parallel?(nil, {:run_in_parallel => []}, 'install') ).to be === false
        end

        it 'returns false if opts is false but a matching mode is specified in options' do
          expect( subject.run_in_parallel?({:run_in_parallel => false}, {:run_in_parallel => ['install']}, 'install') ).to be === false
        end

      end
    end
  end
end
