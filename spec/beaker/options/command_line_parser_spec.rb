require "spec_helper"

module Beaker
  module Options
    describe CommandLineParser do

      let(:parser) {Beaker::Options::CommandLineParser.new}
      let(:test_opts) {["-h", "vcloud.cfg", "--debug", "--tests", "test.rb", "--help"]}
      let(:full_opts) {["--hosts", "host.cfg", "--options", "opts_file", "--type", "pe", "--helper", "path_to_helper", "--load-path", "load_path", "--tests", "test1.rb,test2.rb,test3.rb", "--pre-suite", "pre_suite.rb", "--post-suite", "post_suite.rb", "--no-provision", "--preserve-hosts", "always", "--root-keys", "--keyfile", "../.ssh/id_rsa", "--install", "gitrepopath", "-m", "module", "-q", "--dry-run", "--no-ntp", "--repo-proxy", "--add-el-extras", "--config", "anotherfile.cfg", "--fail-mode", "fast", "--no-color", "--version", "--log-level", "info", "--package-proxy", "http://192.168.100.1:3128", "--collect-perf-data", "--parse-only", "--validate", "--timeout", "40"]}
      let(:validate_true)  {["--validate"]}
      let(:validate_false) {["--no-validate"]}
      let(:configure_true)  {['--configure']}
      let(:configure_false) {['--no-configure']}


      it "can correctly read command line input" do
        expect(parser.parse(test_opts)).to be === {:hosts_file=>"vcloud.cfg", :log_level=>"debug", :tests=>"test.rb", :help=>true}
      end

      it "supports all our command line options" do
        expect(parser.parse(full_opts)).to be === {:hosts_file=>"anotherfile.cfg", :options_file=>"opts_file", :type=>"pe", :helper=>"path_to_helper", :load_path=>"load_path", :tests=>"test1.rb,test2.rb,test3.rb", :pre_suite=>"pre_suite.rb", :post_suite=>"post_suite.rb", :provision=>false, :preserve_hosts=>"always", :root_keys=>true, :keyfile=>"../.ssh/id_rsa", :install=>"gitrepopath", :modules=>"module", :quiet=>true, :dry_run=>true, :timesync=>false, :repo_proxy=>true, :add_el_extras=>true, :fail_mode=>"fast", :color=>false, :version=>true, :log_level=>"info", :package_proxy => "http://192.168.100.1:3128", :collect_perf_data=>true, :parse_only=>true, :validate=>true, :timeout=>"40"}
      end

      it "supports both validate options" do
        expect(parser.parse(validate_true)).to be === {:validate=>true}
        expect(parser.parse(validate_false)).to be === {:validate=>false}
      end

      it 'supports both configure options' do
        expect(parser.parse(configure_true)).to be === {:configure=>true}
        expect(parser.parse(configure_false)).to be === {:configure=>false}
      end

      it "can produce a usage description" do
        expect{parser.usage}.to_not raise_error 
      end

    end
  end
end
