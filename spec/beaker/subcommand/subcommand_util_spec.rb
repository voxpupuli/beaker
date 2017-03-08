require 'spec_helper'

module Beaker
  module Subcommands
    describe SubcommandUtil do

      let(:cli) {
        double("cli")
      }

      let(:rake) {
        double("rake")
      }

      let(:file) {
        double("file")
      }

      let(:store) {
        double("store")
      }

      let(:host) {
        double("host")
      }

      describe 'reset_argv' do
        it "resets argv" do
          args = ["test1", "test2"]
          expect(ARGV).to receive(:clear).exactly(1).times
          subject.reset_argv(args)
          expect(ARGV[0]).to eq(args[0])
          expect(ARGV[1]).to eq(args[1])
        end
      end

      describe 'execute_subcommand' do
        it "determines if we should execute the init subcommand" do
          expect(subject.execute_subcommand?("init")).to be == true
        end
        it "does not attempt to execute intialize as a subcommand" do
          expect(subject.execute_subcommand?("initialize")).to be == false
        end
        it "determines if we should execute the help subcommand" do
          expect(subject.execute_subcommand?("help")).to be == true
        end
        it "determines if we should execute the provision subcommand" do
          expect(subject.execute_subcommand?("provision")).to be == true
        end
        it "determines that a subcommand should not be executed" do
          expect(subject.execute_subcommand?("notasubcommand")).to be == false
        end
      end

      describe 'execute_beaker' do
        it "executes beaker with arguments" do
          allow(cli).to receive(:execute!).and_return(true)
          allow(Beaker::CLI).to receive(:new).and_return(cli)
          expect(subject).to receive(:reset_argv).exactly(1).times
          expect(cli).to receive(:execute!).exactly(1).times
          subject.execute_beaker(['args'])
        end
      end

      describe 'error_with' do
        it "the exit value should default to 1" do
          expect(STDOUT).to receive(:puts).with("exiting").exactly(1).times
          begin
            subject.error_with("exiting")
          rescue SystemExit=>e
            expect(e.status).to eq(1)
          end
        end
        it "the exit value should return specified value" do
          expect(STDOUT).to receive(:puts).with("exiting").exactly(1).times
          begin
            subject.error_with("exiting", {exit_code: 3})
          rescue SystemExit=>e
            expect(e.status).to eq(3)
          end
        end

        it "the exit value should default to 1 with a stack trace" do
          expect(STDOUT).to receive(:puts).with("exiting").exactly(1).times
          expect(STDOUT).to receive(:puts).with("testing").exactly(1).times
          begin
            subject.error_with("exiting", {stack_trace: "testing"})
          rescue SystemExit=>e
            expect(e.status).to eq(1)
          end
        end
      end

      describe 'init_vmpooler' do
        it "executes the vmpooler quick task" do
          expect(subject).to receive(:execute_rake_task).with("beaker_quickstart:gen_hosts[vmpooler]").exactly(1).times
          subject.init_vmpooler
        end
      end

      describe 'init_vagrant' do
        it "executes the vmpooler quick task" do
          expect(subject).to receive(:execute_rake_task).with("beaker_quickstart:gen_hosts[vagrant]").exactly(1).times
          subject.init_vagrant
        end
      end

      describe 'init_hypervisor' do
        it "calls init_vagrant" do
          expect(subject).to receive(:init_vagrant).with(no_args).exactly(1).times
          expect(subject).to receive(:init_vmpooler).with(no_args).exactly(0).times
          subject.init_hypervisor('vagrant')
        end

        it "calls init_vmpooler" do
          expect(subject).to receive(:init_vagrant).with(no_args).exactly(0).times
          expect(subject).to receive(:init_vmpooler).with(no_args).exactly(1).times
          subject.init_hypervisor('vmpooler')
        end

        it "fails to call init for a hypervisor" do
          expect(subject).to receive(:init_vagrant).with(no_args).exactly(0).times
          expect(subject).to receive(:init_vmpooler).with(no_args).exactly(0).times
          subject.init_hypervisor('invalid')
        end
      end

      describe 'execute_rake_task' do

        it "executes the rake task" do
          allow(Rake).to receive(:application).and_return(rake)
          expect(ARGV).to receive(:clear).exactly(1).times
          expect(rake).to receive(:init).and_return(true).exactly(1).times
          expect(rake).to receive(:load_rakefile).and_return(true).exactly(1).times
          expect(rake).to receive(:invoke_task).with("mytask").exactly(1).times
          subject.execute_rake_task("mytask")
        end
      end

      describe "determine_rake_file" do

        it "uses Rakefile if no rakefile exists" do
          allow(subject).to receive(:rake_app).and_return(rake)
          allow(rake).to receive(:find_rakefile_location).and_return(nil)
          expect subject.determine_rake_file == "Rakefile"
        end

        it "uses Rakefile if Rakefile exists" do
          allow(subject).to receive(:rake_app).and_return(rake)
          allow(rake).to receive(:find_rakefile_location).and_return("Rakefile")
          expect subject.determine_rake_file == "Rakefile"
        end

        it "uses rakefile if rakefile exists" do
          allow(subject).to receive(:rake_app).and_return(rake)
          allow(rake).to receive(:find_rakefile_location).and_return("rakefile")
          expect subject.determine_rake_file == "rakefile"
        end

        it "uses Rakefile.rb if Rakefile.rb exists" do
          allow(subject).to receive(:rake_app).and_return(rake)
          allow(rake).to receive(:find_rakefile_location).and_return("Rakefile.rb")
          expect subject.determine_rake_file == "Rakefile.rb"
        end

        it "uses rakefile.rb if rakefile.rb exists" do
          allow(subject).to receive(:rake_app).and_return(rake)
          allow(rake).to receive(:find_rakefile_location).and_return("rakefile.rb")
          expect subject.determine_rake_file == "rakefile.rb"
        end
      end

      describe "require_tasks" do
        it "appends the require if it isn't contained in the Rakefile" do
          allow(subject).to receive(:determine_rake_file).and_return("Rakefile")
          allow(File).to receive(:readlines).with("Rakefile").and_return([""])
          allow(File).to receive(:open).with("Rakefile", "a+").and_yield(file)
          allow(File).to receive(:puts).with("require 'beaker/tasks/quick_start'").and_return(true)
          expect(FileUtils).to receive(:touch).with("Rakefile").exactly(1).times
          expect(File).to receive(:open).with("Rakefile", "a+").and_yield(file).exactly(1).times
          expect(file).to receive(:puts).with("require 'beaker/tasks/quick_start'").exactly(1).times
          subject.require_tasks
        end

        it "does't append the require if it is contained in the Rakefile" do
          allow(subject).to receive(:determine_rake_file).and_return("Rakefile")
          allow(File).to receive(:readlines).with("Rakefile").and_return(["require 'beaker/tasks/quick_start'"])
          allow(File).to receive(:open).with("Rakefile", "a+").and_yield(file)
          allow(File).to receive(:puts).with("require 'beaker/tasks/quick_start'").and_return(true)
          expect(FileUtils).to receive(:touch).with("Rakefile").exactly(1).times
          expect(File).to receive(:open).with("Rakefile", "a+").and_yield(file).exactly(0).times
          expect(file).to receive(:puts).with("require 'beaker/tasks/quick_start'").exactly(0).times
          subject.require_tasks
        end
      end

      describe "init_config" do
        it "creates a .beaker folder and loads the config" do
          expect(FileUtils).to receive(:mkdir_p).with(".beaker").exactly(1).times
          expect(YAML::Store).to receive(:new).with(".beaker/config").exactly(1).times
          subject.init_config
        end
      end

      describe "store_config" do
        before(:each) { SubcommandUtil.class_variable_set :@@store, store} 

        it "stores some values in the YAML store" do
          options = { :hypervisor => "vmpooler", :test => "abc", :provisioned => true}
          allow(store).to receive(:transaction).and_yield
          expect(store).to receive(:[]=).with(:hypervisor, "vmpooler").exactly(1).times
          expect(store).to receive(:[]=).with(:test, "abc").exactly(0).times
          expect(store).to receive(:[]=).with(:provisioned, true).exactly(1).times
          subject.store_config(options)
        end

        it "stores all values in the YAML store" do
          options = { :hypervisor => "vmpooler", :provisioned => true}
          allow(store).to receive(:transaction).and_yield
          expect(store).to receive(:[]=).with(:hypervisor, "vmpooler").exactly(1).times
          expect(store).to receive(:[]=).with(:provisioned, true).exactly(1).times
          subject.store_config(options)
        end

        it "stores no values in the YAML store" do
          options = {:test => "abc"}
          allow(store).to receive(:transaction).and_yield
          expect(store).to receive(:[]=).with(:hypervisor, anything).exactly(0).times
          expect(store).to receive(:[]=).with(:provisioned, anything).exactly(0).times
          subject.store_config(options)
        end
      end

      describe "delete_config" do
        before(:each) { SubcommandUtil.class_variable_set :@@store, store} 
        it "deletes keys from the YAML store" do
          keys = [ :hypervisor, :test, :provisioned ]
          allow(store).to receive(:transaction).and_yield
          expect(store).to receive(:delete).with(:hypervisor).exactly(1).times
          expect(store).to receive(:delete).with(:test).exactly(1).times
          expect(store).to receive(:delete).with(:provisioned).exactly(1).times
          subject.delete_config(keys)
        end
      end

      describe "provision" do
        it "provisions, validates, and configures with vmpooler" do
          options = {:validate => true, :configure => true}
          expect(cli).to receive(:provision).and_return(true)
          expect(cli).to receive(:preserve_hosts_file).exactly(1).times
          allow(Beaker::CLI).to receive(:new).and_return(cli)
          hypervisor = "vmpooler"
          expect(subject).to receive(:reset_argv).with(["--hosts",".beaker/acceptance/config/default_#{hypervisor}_hosts.yaml", "--validate", true, "--configure", true]).exactly(1).times
          subject.provision(hypervisor, options)
        end

        it "provisions and validates with vmpooler" do
          options = {:validate => true, :configure => false }
          expect(cli).to receive(:provision).and_return(true)
          expect(cli).to receive(:preserve_hosts_file).exactly(1).times
          allow(Beaker::CLI).to receive(:new).and_return(cli)
          hypervisor = "vmpooler"
          expect(subject).to receive(:reset_argv).with(["--hosts",".beaker/acceptance/config/default_#{hypervisor}_hosts.yaml", "--validate", true, "--configure", false]).exactly(1).times
          subject.provision(hypervisor, options)
        end

        it "only provisions with vmpooler" do
          options = {:validate => false, :configure => false }
          expect(cli).to receive(:provision).and_return(true)
          expect(cli).to receive(:preserve_hosts_file).exactly(1).times
          allow(Beaker::CLI).to receive(:new).and_return(cli)
          hypervisor = "vmpooler"
          expect(subject).to receive(:reset_argv).with(["--hosts",".beaker/acceptance/config/default_#{hypervisor}_hosts.yaml", "--validate", false, "--configure", false]).exactly(1).times
          subject.provision(hypervisor, options)
        end
      end
    end
  end
end
