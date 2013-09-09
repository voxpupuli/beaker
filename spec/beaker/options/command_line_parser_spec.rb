require "spec_helper"

module Beaker
  module Options
    describe CommandLineParser do

      let(:parser) {Beaker::Options::CommandLineParser.new}
      let(:test_opts) {["-h", "vcloud.cfg", "--debug", "--tests", "test.rb", "--help"]}
      let(:full_opts) {["--hosts", "host.cfg", "--options", "opts_file", "--type", "pe", "--helper", "path_to_helper", "--load-path", "load_path", "--tests", "test1.rb,test2.rb,test3.rb", "--pre-suite", "pre_suite.rb", "--post-suite", "post_suite.rb", "--no-provision", "--preserve-hosts", "--root-keys", "--keyfile", "../.ssh/id_rsa", "--install", "gitrepopath", "-m", "module", "-q", "--no-xml", "--dry-run", "--no-ntp", "--repo-proxy", "--add-el-extras", "--config", "anotherfile.cfg", "--fail-mode", "fast", "--no-color"]}

      it "can correctly read command line input" do
        expect(parser.parse!(test_opts)).to be === {:hosts_file=>"vcloud.cfg", :debug=>true, :tests=>"test.rb", :help=>true}
      end

      it "supports all our command line options" do
        expect(parser.parse!(full_opts)).to be === {:hosts_file=>"anotherfile.cfg", :options_file=>"opts_file", :type=>"pe", :helper=>"path_to_helper", :load_path=>"load_path", :tests=>"test1.rb,test2.rb,test3.rb", :pre_suite=>"pre_suite.rb", :post_suite=>"post_suite.rb", :provision=>false, :preserve_hosts=>true, :root_keys=>true, :ssh=>{:keys=>["../.ssh/id_rsa"]}, :install=>"gitrepopath", :modules=>"module", :quiet=>true, :xml=>false, :dry_run=>true, :timesync=>false, :repo_proxy=>true, :add_el_extras=>true, :fail_mode=>"fast", :color=>false}
      end

      it "can produce a usage description" do
        expect{parser.usage}.to_not raise_error 
      end

    end
  end
end
