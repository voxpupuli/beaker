require 'spec_helper'

module Beaker
  module Options

    describe Validator do
      let(:validator) { Validator.new }

      describe '#check_yaml_file' do
        let(:bad_yaml_path) { File.join(File.expand_path(File.dirname(__FILE__)), 'data', 'badyaml.cfg') }
        let(:yaml_path) { File.join(File.expand_path(File.dirname(__FILE__)), 'data', 'hosts.cfg') }

        before :each do
          FakeFS.deactivate!
        end

        it 'raises error on improperly formatted yaml file' do
          expect { validator.check_yaml_file(bad_yaml_path) }.to raise_error(ArgumentError)
        end

        it 'raises an error when a yaml file is missing' do
          expect { validator.check_yaml_file('not a path') }.to raise_error(ArgumentError)
        end

        it 'does not throw errors on valid yaml files' do
          expect { validator.check_yaml_file(yaml_path) }.to_not raise_error
        end
      end

      describe '#validator_error' do
        it 'raises error with message' do
          expect { validator.validator_error('test error') }.to raise_error(ArgumentError, 'test error')
        end
      end

      describe '#default_set?' do
        it 'is false when empty' do
          expect(validator.default_set?([])).to be_falsey
        end

        it 'throws error when more than 1' do
          expect { validator.default_set?([1, 2]) }.to raise_error(ArgumentError)
        end

        ['test', 1, 3.4, true, Object.new].each do |val|
          it "is true when contents are #{val.class}" do
            expect(validator.default_set?([val])).to be_truthy
          end
        end
      end

      describe '#valid_fail_mode?' do
        %w(stop fast slow).each do |val|
          it "does not throw error when set to #{val}" do
            expect { validator.validate_fail_mode(val) }.to_not raise_error
          end

          it "raises error when set to #{val.upcase}" do
            expect { validator.validate_fail_mode(val.upcase) }.to raise_error(ArgumentError)
          end

          it "raises error when set to #{val.capitalize}" do
            expect { validator.validate_fail_mode(val.capitalize) }.to raise_error(ArgumentError)
          end
        end

        ['test', 1, true, Object.new].each do |val|
          it 'raises error with invalid mode' do
            expect { validator.validate_fail_mode(val) }.to raise_error(ArgumentError)
          end
        end
      end

      describe '#valid_preserve_hosts?' do
        %w(always onfail onpass never).each do |val|
          it "does not raise error when set to #{val}" do
            expect { validator.validate_preserve_hosts(val) }.to_not raise_error
          end

          it "raises error when set to #{val.upcase}" do
            expect { validator.validate_preserve_hosts(val.upcase) }.to raise_error(ArgumentError)
          end

          it "raises error when set to #{val.capitalize}" do
            expect { validator.validate_preserve_hosts(val.capitalize) }.to raise_error(ArgumentError)
          end
        end

        ['test', 1, true, Object.new].each do |val|
          it 'raises error with invalid setting' do
            expect { validator.validate_preserve_hosts(val) }.to raise_error(ArgumentError)
          end
        end
      end

      describe '#validate_tags' do
        it 'does error if tags overlap' do
          tag_includes = %w(can tommies should_error potatoes plant)
          tag_excludes = %w(joey long_running pants should_error)

          expect { validator.validate_tags(tag_includes, tag_excludes) }.to raise_error(ArgumentError)
        end

        it 'does not raise an error if tags do not overlap' do
          tag_includes = %w(horse dog cat)
          tag_excludes = %w(car truck train)

          expect { validator.validate_tags(tag_includes, tag_excludes) }.to_not raise_error
        end
      end

      describe '#validate_frictionless_roles' do
        it 'does nothing when roles are correct' do
          expect { validator.validate_frictionless_roles(%w(frictionless)) }.to_not raise_error
          expect { validator.validate_frictionless_roles(%w(frictionless agent)) }.to_not raise_error
          expect { validator.validate_frictionless_roles(%w(frictionless test1)) }.to_not raise_error
          expect { validator.validate_frictionless_roles(%w(frictionless a role)) }.to_not raise_error
          expect { validator.validate_frictionless_roles(%w(frictionless frictionless some_role)) }.to_not raise_error
        end

        it 'throws errors when roles conflict' do
          expect { validator.validate_frictionless_roles(%w(frictionless master)) }.to raise_error(ArgumentError)
          expect { validator.validate_frictionless_roles(%w(frictionless database)) }.to raise_error(ArgumentError)
          expect { validator.validate_frictionless_roles(%w(frictionless dashboard)) }.to raise_error(ArgumentError)
          expect { validator.validate_frictionless_roles(%w(frictionless console)) }.to raise_error(ArgumentError)
          expect { validator.validate_frictionless_roles(%w(frictionless master database dashboard console)) }.to raise_error(ArgumentError)
        end
      end

      describe '#validate_master_count' do
        it 'does nothing when count is exactly 1' do
          expect { validator.validate_master_count(1) }.to_not raise_error
        end

        it 'throws errors when greater than 1' do
          expect { validator.validate_master_count(2) }.to raise_error(ArgumentError, /one host\/node/)
          expect { validator.validate_master_count(5) }.to raise_error(ArgumentError, /one host\/node/)
          expect { validator.validate_master_count(100) }.to raise_error(ArgumentError, /one host\/node/)
        end
      end

      describe '#validate_files' do
        it 'does not throw an error with non-empty list' do
          expect { validator.validate_files(['filea'], '.') }.to_not raise_error
          expect { validator.validate_files(%w(filea fileb), '.') }.to_not raise_error
        end

        it 'raises error when file list is empty' do
          expect { validator.validate_files([], '.') }.to raise_error(ArgumentError)
        end
      end

      describe '#validate_path' do
        it 'does not throw an error when path is valid' do
          FakeFS do
            expect { validator.validate_path('.') }.to_not raise_error
          end
        end

        it 'throws an error whe path is invalid' do
          expect { validator.validate_path('/tmp/doesnotexist_test') }.to raise_error(ArgumentError)
        end
      end

      describe '#validate_platform' do
        let(:valid_platform) { {'platform' => 'test1'} }
        let(:blank_platform) { {'platform' => ''} }

        it 'does not throw an error when host has a platform' do
          expect { validator.validate_platform(valid_platform, 'vm1') }.to_not raise_error
        end

        it 'throws an error when platform is not included' do
          expect { validator.validate_platform({}, 'vm1') }.to raise_error(ArgumentError, /Host vm1 does not/)
          expect { validator.validate_platform(blank_platform, 'vm2') }.to raise_error(ArgumentError, /Host vm2 does not/)
        end
      end
    end
  end
end
