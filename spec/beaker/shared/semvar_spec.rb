require 'spec_helper'

module Beaker
  module Shared
    describe Semvar do

      describe 'version_is_less' do

        it 'reports 2015.3.0-rc0-8-gf80879a is less than 2016' do
          expect( subject.version_is_less( '2015.3.0-rc0-8-gf80879a', '2016' ) ).to be === true
        end

        it 'reports 2015.3.0-rc0-8-gf80879a is less than 2015.3.0' do
          expect( subject.version_is_less( '2015.3.0-rc0-8-gf80879a', '2015.3.0' ) ).to be === true
        end

        it 'reports that 2015.3.0-rc0 is less than 2015.3.0-rc0-8-gf80879a' do
          expect( subject.version_is_less( '2015.3.0-rc0', '2015.3.0-rc0-8-gf80879a' ) ).to be === true
        end

        it 'reports that 2015.3.0-rc2 is less than 2015.3.0-rc10 (not using string comparison)' do
          expect( subject.version_is_less( '2015.3.0-rc2', '2015.3.0-rc10' ) ).to be === true
        end

        it 'reports that 2015.3.0 is less than 2015.3.0-1-gabc1234' do
          expect( subject.version_is_less( '2015.3.0', '2015.3.0-1-gabc1234' ) ).to be === true
        end

        it 'reports that 2015.3.0-rc2 is less than 2015.3.0-1-gabc1234' do 
          expect( subject.version_is_less( '2015.3.0-rc2', '2015.3.0-1-gabc1234' ) ).to be === true
        end

        it 'reports 2015.3.0-rc0-8-gf80879a is not less than 3.0.0' do
          expect( subject.version_is_less( '2015.3.0-rc0-8-gf80879a', '3.0.0' ) ).to be === false
        end

        it 'reports 3.0.0-160-gac44cfb is not less than 3.0.0' do
          expect( subject.version_is_less( '3.0.0-160-gac44cfb', '3.0.0' ) ).to be === false
        end

        it 'reports 3.0.0-160-gac44cfb is not less than 2.8.2' do
          expect( subject.version_is_less( '3.0.0-160-gac44cfb', '2.8.2' ) ).to be === false
        end

        it 'reports 3.0.0 is less than 3.0.0-160-gac44cfb' do
          expect( subject.version_is_less( '3.0.0', '3.0.0-160-gac44cfb' ) ).to be === true
        end

        it 'reports 2.8.2 is less than 3.0.0-160-gac44cfb' do
          expect( subject.version_is_less( '2.8.2', '3.0.0-160-gac44cfb' ) ).to be === true
        end

        it 'reports 2.8 is less than 3.0.0-160-gac44cfb' do
          expect( subject.version_is_less( '2.8', '3.0.0-160-gac44cfb' ) ).to be === true
        end

        it 'reports 2.8 is less than 2.9' do
          expect( subject.version_is_less( '2.8', '2.9' ) ).to be === true
        end

        it 'reports that 2015.3.0 is not less than 2015.3.0' do
          expect( subject.version_is_less( '2015.3.0', '2015.3.0' ) ).to be == false
        end
      end

      describe 'max_version' do

        it 'returns nil if versions isn\'t defined' do
          expect( subject.max_version(nil) ).to be_nil
        end

        it 'returns nil if versions is empty' do
          expect( subject.max_version([]) ).to be_nil
        end

        it 'allows you to set the default, & will return it with faulty input' do
          expect( subject.max_version([], '5.9') ).to be === '5.9'
        end

        it 'returns the one value if given a length 1 array' do
          expect( subject.max_version(['7.3']) ).to be === '7.3'
        end

        it 'does not mangle the versions array passed in' do
          first_array = ['1.4.3', '8.4.5', '3.5.7', '2.7.5']
          array_to_pass = first_array.dup
          subject.max_version(array_to_pass)
          expect( array_to_pass ).to be === first_array
        end

        it 'returns 5.8.9 from [5.8.9, 1.2.3, 0.3.5, 5.7.11]' do
          expect( subject.max_version(['5.8.9', '1.2.3', '0.3.5', '5.7.11']) ).to be === '5.8.9'
        end

      end
    end

  end
end
