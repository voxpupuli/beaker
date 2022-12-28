require "spec_helper"

module Beaker
  module Options
    describe CommandLineParser do

      let(:parser) {described_class.new}
      let(:test_opts) {["-h", "vcloud.cfg", "--debug", "--tests", "test.rb", "--help"]}
      let(:full_opts_in)  {["--hosts", "host.cfg",           "--options", "opts_file", "--helper", "path_to_helper", "--load-path", "load_path", "--tests", "test1.rb,test2.rb,test3.rb", "--pre-suite", "pre_suite.rb", "--post-suite", "post_suite.rb", "--pre-cleanup", "pre_cleanup.rb", "--no-provision", "--preserve-hosts", "always",   "--root-keys", "--keyfile", "../.ssh/id_rsa", "--install", "gitrepopath",     "-m", "module",         "-q",    "--dry-run",       "--no-ntp",    "--repo-proxy",    "--add-el-extras", "--config", "anotherfile.cfg", "--fail-mode", "fast",  "--no-color", "--no-color-host-output",                 "--version", "--log-level", "info", "--package-proxy", "http://192.168.100.1:3128",        "--collect-perf-data",    "--parse-only",    "--validate", "--timeout", "40", "--log-prefix", "pants",      "--configure", "--test-tag-and", "1,2,3", "--test-tag-or", "4,5,6", "--test-tag-exclude", "7,8,9",        "--xml-time-order"]}
      let(:full_opts_out) {{:hosts_file=>"anotherfile.cfg",:options_file=>"opts_file",  :helper => "path_to_helper",  :load_path => "load_path",  :tests => "test1.rb,test2.rb,test3.rb",  :pre_suite => "pre_suite.rb",  :post_suite => "post_suite.rb", :pre_cleanup => "pre_cleanup.rb", :provision=>false, :preserve_hosts => "always", :root_keys=>true, :keyfile => "../.ssh/id_rsa",  :install => "gitrepopath", :modules=>"module", :quiet=>true, :dry_run=>true, :timesync=>false, :repo_proxy=>true, :add_el_extras=>true,                                 :fail_mode => "fast", :color=>false, :color_host_output=>false, :beaker_version_print=>true,  :log_level => "info",  :package_proxy => "http://192.168.100.1:3128", :collect_perf_data=>"normal", :parse_only=>true, :validate=>true,  :timeout => "40",  :log_prefix => "pants", :configure => true,  :test_tag_and => "1,2,3",  :test_tag_or => "4,5,6",  :test_tag_exclude => "7,8,9", :xml_time_enabled => true}}
      let(:validate_true)  {["--validate"]}
      let(:validate_false) {["--no-validate"]}
      let(:configure_true)  {['--configure']}
      let(:configure_false) {['--no-configure']}
      let(:provision_false) {['--no-provision']}
      let(:provision_other) {{:provision => false, :configure => false, :validate => false}}
      let(:provision_both_in)   {['--no-provision', '--configure', '--validate']}
      let(:provision_both_out)  {{:provision => false, :configure => true, :validate => true}}
      let(:provision_half_in)   {['--no-provision', '--configure']}
      let(:provision_half_out)  {{:provision => false, :configure => true, :validate => false}}


      it "can correctly read command line input" do
        expect(parser.parse(test_opts)).to be === {:hosts_file=>"vcloud.cfg", :log_level=>"debug", :tests=>"test.rb", :help=>true}
      end

      it "supports all our command line options" do
        expect(parser.parse(full_opts_in)).to be === full_opts_out
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
        expect{parser.usage}.not_to raise_error
      end

      context '--no-provision flag effects other options' do
        it 'sets --no-validate/configure when --no-provision is set' do
          expect(parser.parse(provision_false)).to be === provision_other
        end

        it 'can still have --validate & --configure set correctly when --no-provision is set' do
          expect(parser.parse(provision_both_in)).to be === provision_both_out
        end

        it 'can override just one of the two flags when --no-provision is set' do
          expect(parser.parse(provision_half_in)).to be === provision_half_out
        end
      end

    end
  end
end
