require 'spec_helper'

module Beaker
  describe Unix::Pkg do
    class UnixPkgTest
      include Unix::Pkg

      def initialize(hash, logger)
        @hash = hash
        @logger = logger
      end

      def [](k)
        @hash[k]
      end

      def to_s
        "me"
      end

      def exec
        #noop
      end

    end

    let (:opts)     { @opts || {} }
    let (:logger)   { double( 'logger' ).as_null_object }
    let (:instance) { UnixPkgTest.new(opts, logger) }

    context "check_for_package" do

      it "checks correctly on sles" do
        @opts = {'platform' => 'sles-is-me'}
        pkg = 'sles_package'
        expect( Beaker::Command ).to receive(:new).with("zypper se -i --match-exact #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', :accept_all_exit_codes => true).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end
 
      it "checks correctly on fedora" do
        @opts = {'platform' => 'fedora-is-me'}
        pkg = 'fedora_package'
        expect( Beaker::Command ).to receive(:new).with("rpm -q #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', :accept_all_exit_codes => true).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on centos" do
        @opts = {'platform' => 'centos-is-me'}
        pkg = 'centos_package'
        expect( Beaker::Command ).to receive(:new).with("rpm -q #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', :accept_all_exit_codes => true).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on EOS" do
        @opts = {'platform' => 'eos-is-me'}
        pkg = 'eos-package'
        expect( Beaker::Command ).to receive(:new).with("rpm -q #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', :accept_all_exit_codes => true).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on el-" do
        @opts = {'platform' => 'el-is-me'}
        pkg = 'el_package'
        expect( Beaker::Command ).to receive(:new).with("rpm -q #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', :accept_all_exit_codes => true).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on debian" do
        @opts = {'platform' => 'debian-is-me'}
        pkg = 'debian_package'
        expect( Beaker::Command ).to receive(:new).with("dpkg -s #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', :accept_all_exit_codes => true).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on ubuntu" do
        @opts = {'platform' => 'ubuntu-is-me'}
        pkg = 'ubuntu_package'
        expect( Beaker::Command ).to receive(:new).with("dpkg -s #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', :accept_all_exit_codes => true).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on cumulus" do
        @opts = {'platform' => 'cumulus-is-me'}
        pkg = 'cumulus_package'
        expect( Beaker::Command ).to receive(:new).with("dpkg -s #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', :accept_all_exit_codes => true).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on solaris-11" do
        @opts = {'platform' => 'solaris-11-is-me'}
        pkg = 'solaris-11_package'
        expect( Beaker::Command ).to receive(:new).with("pkg info #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', :accept_all_exit_codes => true).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "checks correctly on solaris-10" do
        @opts = {'platform' => 'solaris-10-is-me'}
        pkg = 'solaris-10_package'
        expect( Beaker::Command ).to receive(:new).with("pkginfo #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', :accept_all_exit_codes => true).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.check_for_package(pkg) ).to be === true
      end

      it "returns false for el-4" do
        @opts = {'platform' => 'el-4-is-me'}
        pkg = 'el-4_package'
        expect( instance.check_for_package(pkg) ).to be === false
      end

      it "raises on unknown platform" do
        @opts = {'platform' => 'nope-is-me'}
        pkg = 'nope_package'
        expect{ instance.check_for_package(pkg) }.to raise_error

      end

    end

    context "install_package" do

      it "uses yum on fedora-20" do
        @opts = {'platform' => 'fedora-20-is-me'}
        pkg = 'fedora_package'
        expect( Beaker::Command ).to receive(:new).with("yum -y  install #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.install_package(pkg) ).to be == "hello"
      end

      it "uses dnf on fedora-22" do
        @opts = {'platform' => 'fedora-22-is-me'}
        pkg = 'fedora_package'
        expect( Beaker::Command ).to receive(:new).with("dnf -y  install #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.install_package(pkg) ).to be == "hello"
      end
    end

    context "install_package_with_rpm" do

      it "accepts a package as a single argument" do
        @opts = {'platform' => 'el-is-me'}
        pkg = 'redhat_package'
        expect( Beaker::Command ).to receive(:new).with("rpm  -ivh #{pkg} ", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.install_package_with_rpm(pkg) ).to be == "hello"
      end

      it "accepts a package and additional options" do
        @opts = {'platform' => 'el-is-me'}
        pkg = 'redhat_package'
        cmdline_args = '--foo'
        expect( Beaker::Command ).to receive(:new).with("rpm #{cmdline_args} -ivh #{pkg} ", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.install_package_with_rpm(pkg, cmdline_args) ).to be == "hello"
      end

    end

    context 'extract_rpm_proxy_options' do

      [ 'http://myproxy.com:3128/',
        'https://myproxy.com:3128/',
        'https://myproxy.com:3128',
        'http://myproxy.com:3128',
      ].each do |url|
        it "correctly extracts rpm proxy options for #{url}" do
          expect( instance.extract_rpm_proxy_options(url) ).to be == '--httpproxy myproxy.com --httpport 3128'
        end
      end

      url = 'http:/myproxy.com:3128'
      it "fails to extract rpm proxy options for #{url}" do
        expect{
          instance.extract_rpm_proxy_options(url)
        }.to raise_error(RuntimeError, /Cannot extract host and port/)
      end

    end

    context '#pe_puppet_agent_promoted_package_install' do
      context 'on solaris platforms' do
        before :each do
          allow( subject ).to receive( :fetch_http_file )
          allow( subject ).to receive( :scp_to )
          allow( subject ).to receive( :configure_type_defaults_on )
        end

        context 'version support' do
          (7..17).each do |version|
            supported_version = version == 10 || version == 11
            supported_str = ( supported_version ? '' : 'not ')
            test_title = "does #{supported_str}support version #{version}"

            it "#{test_title}" do
              solaris_platform = Beaker::Platform.new("solaris-#{version}-x86_64")
              @opts = {'platform' => solaris_platform}
              allow( instance ).to receive( :execute )
              if supported_version
                if version == 10
                  allow( instance ).to receive( :noask_file_text )
                  allow( instance ).to receive( :create_remote_file )
                end
                # only expect diff in the last line: .not_to vs .to raise_error
                expect{
                  instance.pe_puppet_agent_promoted_package_install(
                    'oh_cp_base', 'oh_cp_dl', 'oh_cp_fl', 'dl_fl', {}
                  )
                }.not_to raise_error
              else
                expect{
                  instance.pe_puppet_agent_promoted_package_install(
                    'oh_cp_base', 'oh_cp_dl', 'oh_cp_fl', 'dl_fl', {}
                  )
                }.to raise_error(ArgumentError, /^Solaris #{version} is not supported/ )
              end
            end
          end

        end

        context 'on solaris 10' do
          before :each do
            solaris_platform = Beaker::Platform.new('solaris-10-x86_64')
            @opts = {'platform' => solaris_platform}
          end

          it 'sets a noask file' do
            allow( instance ).to receive( :execute )
            expect( instance ).to receive( :noask_file_text )
            expect( instance ).to receive( :create_remote_file )
            instance.pe_puppet_agent_promoted_package_install('', '', '', '', {})
          end

          it 'calls the correct install command' do
            allow( instance ).to receive( :noask_file_text )
            allow( instance ).to receive( :create_remote_file )
            # a number of `execute` calls before the one we're looking for
            allow( instance ).to receive( :execute )
            # actual gunzip call to test
            expect( instance ).to receive( :execute ).with( /^gunzip\ \-c\ / )
            instance.pe_puppet_agent_promoted_package_install(
              'oh_cp_base', 'oh_cp_dl', 'oh_cp_fl', 'dl_fl', {}
            )
          end
        end

        context 'on solaris 11' do
          before :each do
            solaris_platform = Beaker::Platform.new('solaris-11-x86_64')
            @opts = {'platform' => solaris_platform}
          end

          it 'calls the correct install command' do
            # a number of `execute` calls before the one we're looking for
            allow( instance ).to receive( :execute )
            # actual pkg install call to test
            expect( instance ).to receive( :execute ).with( /^pkg\ install\ \-g / ).ordered
            instance.pe_puppet_agent_promoted_package_install(
              'oh_cp_base', 'oh_cp_dl', 'oh_cp_fl', 'dl_fl', {}
            )
          end
        end
      end
    end
  end
end

