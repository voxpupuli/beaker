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
        it "determines if we should execute the help subcommand" do
          expect(subject.execute_subcommand?("help")).to be == true
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

      describe 'exit_with' do
        it "the exit value should be false" do
          expect(STDOUT).to receive(:puts).with("exiting").exactly(1).times
          begin
            subject.exit_with("exiting")
          rescue SystemExit=>e
            expect(e.status).to eq(0)
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
          options = {:hypervisor => "vagrant"}
          expect(subject).to receive(:init_vagrant).with(no_args).exactly(1).times
          expect(subject).to receive(:init_vmpooler).with(no_args).exactly(0).times
          subject.init_hypervisor(options)
        end

        it "calls init_vmpooler" do
          options = {:hypervisor => "vmpooler"}
          expect(subject).to receive(:init_vagrant).with(no_args).exactly(0).times
          expect(subject).to receive(:init_vmpooler).with(no_args).exactly(1).times
          subject.init_hypervisor(options)
        end

        it "fails to call init for a hypervisor" do
          options = {:hypervisor => "invalid"}
          expect(subject).to receive(:init_vagrant).with(no_args).exactly(0).times
          expect(subject).to receive(:init_vmpooler).with(no_args).exactly(0).times
          subject.init_hypervisor(options)
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

      describe 'verify_init_args' do
        it "verfy the init args are valid for a vagrant run" do
          options = {:hypervisor => "vagrant"}
          expect(subject).to receive(:exit_with).exactly(0).times
          subject.verify_init_args(options)
        end

        it "verfy the init args are valid for a vmpooler run" do
          options = {:hypervisor => "vmpooler"}
          expect(subject).to receive(:exit_with).exactly(0).times
          subject.verify_init_args(options)
        end

        it "verify the init args are invalid for an init run" do
          options = {}
          expect(STDOUT).to receive(:puts).with("Invalid hypervisor. Currently supported hypervisors are: #{Beaker::Subcommands::SubcommandUtil::HYPERVISORS.join(', ')}").exactly(1).times
          begin
            subject.verify_init_args(options)
          rescue SystemExit=>e
            expect(e.status).to eq(0)
          end
        end

        it "verify the init args are invalid for a vmpooler run" do
          options = {:hypervisor => "thisshouldfail"}
          expect(STDOUT).to receive(:puts).with("Invalid hypervisor. Currently supported hypervisors are: #{Beaker::Subcommands::SubcommandUtil::HYPERVISORS.join(', ')}").exactly(1).times
          begin
            subject.verify_init_args(options)
          rescue SystemExit=>e
            expect(e.status).to eq(0)
          end
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

    end
  end
end
