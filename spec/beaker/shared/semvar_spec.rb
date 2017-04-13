require 'spec_helper'

module Beaker
  module Shared
    describe Semvar do

      describe 'version_is_less' do

        it 'reports 2015.3.0-rc0-8-gf80879a is less than 2016' do
          expect( subject.version_is_less( '2015.3.0-rc0-8-gf80879a', '2016' ) ).to be === true
        end

        it 'reports 2015.3.0-rc0-8-gf80879a is not less than 2015.3.0' do
          expect( subject.version_is_less( '2015.3.0-rc0-8-gf80879a', '2015.3.0' ) ).to be === false
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
      end

      describe 'PuppetVersion' do
        it 'accepts valid PE non-final builds' do
          ver = '2015.3.0-rc0-8-gf80879a'
          expect( subject::PuppetVersion.new(ver).major ).to be == 2015
          expect( subject::PuppetVersion.new(ver).minor ).to be == 3
          expect( subject::PuppetVersion.new(ver).patch ).to be == 0
          expect( subject::PuppetVersion.new(ver).rc ).to be == 0
          expect( subject::PuppetVersion.new(ver).build ).to be == 8
          expect( subject::PuppetVersion.new(ver).sha ).to be == 'f80879a'
        end

        it 'accepts valid PE final builds' do
          ver = '2015.3.0'
          expect( subject::PuppetVersion.new(ver).major ).to be == 2015
          expect( subject::PuppetVersion.new(ver).minor ).to be == 3
          expect( subject::PuppetVersion.new(ver).patch ).to be == 0
          expect( subject::PuppetVersion.new(ver).rc ).to be == 999
          expect( subject::PuppetVersion.new(ver).build ).to be == 0
          expect( subject::PuppetVersion.new(ver).sha ).to be == nil
        end

        it 'accepts valid PE post-final builds' do
          ver = '2015.3.0-8-gf80879a'
          expect( subject::PuppetVersion.new(ver).major ).to be == 2015
          expect( subject::PuppetVersion.new(ver).minor ).to be == 3
          expect( subject::PuppetVersion.new(ver).patch ).to be == 0
          expect( subject::PuppetVersion.new(ver).rc ).to be == 999
          expect( subject::PuppetVersion.new(ver).build ).to be == 8
          expect( subject::PuppetVersion.new(ver).sha ).to be == 'f80879a'
        end

        it 'accepts valid PE year/release' do
          ver = '2015.3'
          expect( subject::PuppetVersion.new(ver).major ).to be == 2015
          expect( subject::PuppetVersion.new(ver).minor ).to be == 3
          expect( subject::PuppetVersion.new(ver).patch ).to be == 0
          expect( subject::PuppetVersion.new(ver).rc ).to be == 999
          expect( subject::PuppetVersion.new(ver).build ).to be == 0
          expect( subject::PuppetVersion.new(ver).sha ).to be == nil
        end

        it 'accepts valid PE year' do
          ver = '2015'
          expect( subject::PuppetVersion.new(ver).major ).to be == 2015
          expect( subject::PuppetVersion.new(ver).minor ).to be == 0
          expect( subject::PuppetVersion.new(ver).patch ).to be == 0
          expect( subject::PuppetVersion.new(ver).rc ).to be == 999
          expect( subject::PuppetVersion.new(ver).build ).to be == 0
          expect( subject::PuppetVersion.new(ver).sha ).to be == nil
        end

        it 'rejects an invalid semver' do
          expect { subject::PuppetVersion.new('2015.0-3') }.to raise_error(/Unknown format/)
        end

        it 'rejects an invalid PE version' do
          expect { subject::PuppetVersion.new('2015.1.0-rc5-300-null') }.to raise_error(/Unknown format/)
        end

        it 'rejects a non version string' do
          expect { subject::PuppetVersion.new('banana') }.to raise_error(/Unknown format/)
        end
      end

      describe 'puppet_version_comparison' do
        it 'reports 2015.3.0-rc0-8-gf80879a is less than 2016' do
          expect( subject::PuppetVersion.new('2015.3.0-rc0-8-gf80879a') < '2016' ).to be === true
        end

        it 'reports 2016 is greater than 2015.3.0-rc0-8-gf80879a' do
          expect( subject::PuppetVersion.new('2016') > '2015.3.0-rc0-8-gf80879a' ).to be === true
        end

        it 'reports 2015.3.0-rc0-8-gf80879a is equal to 2015.3.0-rc0-8-gf80879a' do
          expect( subject::PuppetVersion.new('2015.3.0-rc0-8-gf80879a') == '2015.3.0-rc0-8-gf80879a' ).to be === true
        end

        it 'reports 2016 is greater than 2015.3.0-rc0-8-gf80879a' do
          expect( subject::PuppetVersion.new('2015.3.0-rc1-4-gabcdef1') > '2015.3.0-rc0-8-gf80879a' ).to be === true
        end

        it 'reports 2016 is greater than 2015.3.0-rc0-8-gf80879a' do
          expect( subject::PuppetVersion.new('2015.2.0-rc1-9-gabcdef1') > '2015.3.0-rc0-8-gf80879a' ).to be === false
        end

        it 'reports 2015.3.0-rc0-8-gf80879a is less than 2015.3.0' do
          expect( subject::PuppetVersion.new('2015.3.0-rc0-8-gf80879a') < '2015.3.0' ).to be === true
        end

        it 'reports 2015.3.0-rc0-8-gf80879a is not less than 3.0.0' do
          expect( subject::PuppetVersion.new('2015.3.0-rc0-8-gf80879a') < '3.0.0' ).to be === false
        end

        it 'can compare 2017.1.0-rc9-100-gabcdef and 2016.2.1' do
          expect( subject::PuppetVersion.new('2017.1.0-rc9-100-gabcdef') > '2016.2.1' ).to be === true
        end

        it 'can compare 2017.1.0-rc9-100-gabcdef and 2016.2.1' do
          expect( subject::PuppetVersion.new('2017.1.0-rc9-100-gabcdef') >= '2016.2.1' ).to be === true
        end

        it 'can compare 2017.1.0-rc9-100-gabcdef and 2016.2.1' do
          expect( subject::PuppetVersion.new('2017.1.0-rc9-100-gabcdef') < '2016.2.1' ).to be === false
        end

        it 'can compare 2017.1.0-rc9-100-gabcdef and 2016.2.1' do
          expect( subject::PuppetVersion.new('2017.1.0-rc9-100-gabcdef') <= '2016.2.1' ).to be === false
        end

        it 'can compare 2017.1.0-rc9-100-gabcdef and 2016.2.1' do
          expect( subject::PuppetVersion.new('2017.1.0-rc9-100-gabcdef') != '2016.2.1' ).to be === true
        end

        it 'can compare 2017.1.0-rc9-100-gabcdef and 2016.2.1' do
          expect( subject::PuppetVersion.new('2017.1.0-rc9-100-gabcdef') == '2016.2.1' ).to be === false
        end

        it 'reports 3.0.0-160-gac44cfb is not less than 3.0.0' do
          expect( subject::PuppetVersion.new('3.0.0-160-gac44cfb') < '3.0.0' ).to be === false
        end

        it 'reports 3.0.0-160-gac44cfb is not less than 2.8.2' do
          expect( subject::PuppetVersion.new('3.0.0-160-gac44cfb') < '2.8.2' ).to be === false
        end

        it 'reports 3.0.0-rc0-160-gac44cfb is less than 3.0.0' do
          expect( subject::PuppetVersion.new('3.0.0-rc0-160-gac44cfb') < '3.0.0' ).to be === true
        end

        it 'reports 3.0.0-rc0-160-gac44cfb is greater than 2.8.0' do
          expect( subject::PuppetVersion.new('3.0.0-rc0-160-gac44cfb') > '2.8.0' ).to be === true
        end

        it 'reports 3.0.0 is less than 3.0.0-160-gac44cfb' do
          expect( subject::PuppetVersion.new('3.0.0') < '3.0.0-160-gac44cfb' ).to be === true
        end

        it 'reports 2.8.2 is less than 3.0.0-160-gac44cfb' do
          expect( subject::PuppetVersion.new('2.8.2') < '3.0.0-160-gac44cfb' ).to be === true
        end

        it 'reports 2.8.0 is less than 3.0.0-160-gac44cfb' do
          expect( subject::PuppetVersion.new('2.8.0') < '3.0.0-160-gac44cfb' ).to be === true
        end

        it 'reports 2.8.0 is less than 2.9.0' do
          expect( subject::PuppetVersion.new('2.8.0') < '2.9.0' ).to be === true
        end

        it 'reports 2.9.0 is greater than 2.8.0' do
          expect( subject::PuppetVersion.new('2.9.0') > '2.8.0' ).to be === true
        end

        it 'reports 2.8 is less than 2.9' do
          expect( subject::PuppetVersion.new('2.8') < '2.9' ).to be === true
        end

        it 'reports 2.8.2 is less than 2.9' do
          expect(subject::PuppetVersion.new('2.8.2') < '2.9').to be === true
        end

        it 'compares two PuppetVersions' do
          expect(subject::PuppetVersion.new('2.8.2') < subject::PuppetVersion.new('2.9')).to be === true
        end

        it 'blows up if you give it an invalid version' do
          expect {
            subject::PuppetVersion.new('a.banana.5') < '2.9'
          }.to raise_error(/Unknown format/)
        end

        it 'blows up if you give it an invalid version' do
          expect {
            subject::PuppetVersion.new('1.2.beta') < '2.9'
          }.to raise_error(/Unknown format/)
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
