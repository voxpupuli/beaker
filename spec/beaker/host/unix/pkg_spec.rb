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

      def []=(k, v)
        @hash[k] = v
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

    context 'Package deployment tests' do
      path = '/some/file/path'
      name = 'package_name'
      version = '1.0.0'

      describe '#deploy_package_repo' do

        it 'returns a warning if there is no file at the path specified' do
          expect(logger).to receive(:warn)
          allow(File).to receive(:exists?).with(path).and_return(false)
          instance.deploy_package_repo(path,name,version)
        end

        it 'calls #deploy_apt_repo for huaweios systems' do
          @opts = {'platform' => 'huaweios-is-me'}
          expect(instance).to receive(:deploy_apt_repo)
          allow(File).to receive(:exists?).with(path).and_return(true)
          instance.deploy_package_repo(path,name,version)
        end

        it 'calls #deploy_apt_repo for debian systems' do
          @opts = {'platform' => 'ubuntu-is-me'}
          expect(instance).to receive(:deploy_apt_repo)
          allow(File).to receive(:exists?).with(path).and_return(true)
          instance.deploy_package_repo(path,name,version)
        end

        it 'calls #deploy_yum_repo for el systems' do
          @opts = {'platform' => 'el-is-me'}
          expect(instance).to receive(:deploy_yum_repo)
          allow(File).to receive(:exists?).with(path).and_return(true)
          instance.deploy_package_repo(path,name,version)
        end

        it 'calls #deploy_zyp_repo for sles systems' do
          @opts = {'platform' => 'sles-is-me'}
          expect(instance).to receive(:deploy_zyp_repo)
          allow(File).to receive(:exists?).with(path).and_return(true)
          instance.deploy_package_repo(path,name,version)
        end

        it 'raises an error for unsupported systems' do
          @opts = {'platform' => 'windows-is-me'}
          allow(File).to receive(:exists?).with(path).and_return(true)
          expect{instance.deploy_package_repo(path,name,version)}.to raise_error(RuntimeError)
        end
      end

      describe '#deploy_apt_repo' do

        it 'warns and exits when no codename exists for the debian platform' do
          @opts = {'platform' => 'ubuntu-is-me'}
          expect(logger).to receive(:warn)
          allow(@opts['platform']).to receive(:codename).and_return(nil)
          expect(instance).to receive(:deploy_apt_repo).and_return(instance.deploy_apt_repo(path,name,version))
          allow(File).to receive(:exists?).with(path).and_return(true)
          instance.deploy_package_repo(path,name,version)
        end
      end
    end

    context "check_for_package" do
      it "checks correctly on sles" do
        @opts = {'platform' => 'sles-is-me'}
        pkg = 'sles_package'
        expect( Beaker::Command ).to receive( :new ).with( /^rpmkeys.*nightlies.puppetlabs.com.*/, anything, anything ).and_return('').ordered.once
        expect( Beaker::Command ).to receive(:new).with("zypper --gpg-auto-import-keys se -i --match-exact #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('').ordered.once
        expect( instance ).to receive(:exec).with('', :accept_all_exit_codes => true).and_return(generate_result("hello", {:exit_code => 0})).exactly(2).times
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

      it "checks correctly on huaweios" do
        @opts = {'platform' => 'huaweios-is-me'}
        pkg = 'debian_package'
        expect( Beaker::Command ).to receive(:new).with("dpkg -s #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
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

      it "checks correctly on archlinux" do
        @opts = {'platform' => 'archlinux-is-me'}
        pkg = 'archlinux_package'
        expect( Beaker::Command ).to receive(:new).with("pacman -Q #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
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

    describe '#update_apt_if_needed' do
      PlatformHelpers::DEBIANPLATFORMS.each do |platform|
        it "calls update for #{platform}" do
          @opts = {'platform' => platform}
          instance.instance_variable_set("@apt_needs_update", true)
          expect(instance).to receive('execute').with("apt-get update")
          expect{instance.update_apt_if_needed}.to_not raise_error
        end
      end
    end
    context "install_package" do

      PlatformHelpers::DEBIANPLATFORMS.each do |platform|
        it "uses apt-get for #{platform}" do
          @opts = {'platform' => platform}
          pkg = 'pkg'
          expect( Beaker::Command ).to receive(:new).with("apt-get install --force-yes  -y #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
          expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
          expect( instance.install_package(pkg) ).to be == "hello"
        end
      end

      (1..21).to_a.each do | fedora_release |
        it "uses yum on fedora-#{fedora_release}" do
          @opts = {'platform' => "fedora-#{fedora_release}-is-me"}
          pkg = 'fedora_package'
          expect( Beaker::Command ).to receive(:new).with("yum -y  install #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
          expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
          expect( instance.install_package(pkg) ).to be == "hello"
        end
      end

      (22..29).to_a.each do | fedora_release |
        it "uses dnf on fedora-#{fedora_release}" do
          @opts = {'platform' => "fedora-#{fedora_release}-is-me"}
          pkg = 'fedora_package'
          expect( Beaker::Command ).to receive(:new).with("dnf -y  install #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
          expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
          expect( instance.install_package(pkg) ).to be == "hello"
        end
      end

      it "uses pacman on archlinux" do
        @opts = {'platform' => 'archlinux-is-me'}
        pkg = 'archlinux_package'
        expect( Beaker::Command ).to receive(:new).with("pacman -S --noconfirm  #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.install_package(pkg) ).to be == "hello"
      end
    end

    describe '#uninstall_package' do
      PlatformHelpers::DEBIANPLATFORMS.each do |platform|
        it "calls pkg uninstall for #{platform}" do
          @opts = {'platform' => platform}
          expect( Beaker::Command ).to receive(:new).with("apt-get purge  -y pkg", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
          expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
          expect(instance.uninstall_package('pkg')).to be == "hello"
        end

        (1..21).to_a.each do | fedora_release |
          it "uses yum on fedora-#{fedora_release}" do
            @opts = {'platform' => "fedora-#{fedora_release}-is-me"}
            pkg = 'fedora_package'
            expect( Beaker::Command ).to receive(:new).with("yum -y  remove #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
            expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
            expect( instance.uninstall_package(pkg) ).to be == "hello"
          end
        end

        (22..29).to_a.each do | fedora_release |
          it "uses dnf on fedora-#{fedora_release}" do
            @opts = {'platform' => "fedora-#{fedora_release}-is-me"}
            pkg = 'fedora_package'
            expect( Beaker::Command ).to receive(:new).with("dnf -y  remove #{pkg}", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
            expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
            expect( instance.uninstall_package(pkg) ).to be == "hello"
          end
        end
      end
    end

    describe '#puppet_agent_dev_package_info' do
      puppet_collection = 'PC1'
      puppet_agent_version = '1.2.3'
      platforms = { 'solaris-10-x86_64' => ["solaris/10/#{puppet_collection}", "puppet-agent-#{puppet_agent_version}-1.i386.pkg.gz"],
                    'solaris-11-x86_64' => ["solaris/11/#{puppet_collection}", "puppet-agent@#{puppet_agent_version},5.11-1.i386.p5p"],
                    'sles-11-x86_64' => ["sles/11/#{puppet_collection}/x86_64", "puppet-agent-#{puppet_agent_version}-1.sles11.x86_64.rpm"],
                    'aix-5.3-power' => ["aix/5.3/#{puppet_collection}/ppc", "puppet-agent-#{puppet_agent_version}-1.aix5.3.ppc.rpm"],
                    'el-7-x86_64' => ["el/7/#{puppet_collection}/x86_64", "puppet-agent-#{puppet_agent_version}-1.el7.x86_64.rpm"],
                    'centos-7-x86_64' => ["el/7/#{puppet_collection}/x86_64", "puppet-agent-#{puppet_agent_version}-1.el7.x86_64.rpm"],
                    'oracle-7-x86_64' => ["el/7/#{puppet_collection}/x86_64", "puppet-agent-#{puppet_agent_version}-1.el7.x86_64.rpm"],
                    'redhat-7-x86_64' => ["el/7/#{puppet_collection}/x86_64", "puppet-agent-#{puppet_agent_version}-1.el7.x86_64.rpm"],
                    'scientific-7-x86_64' => ["el/7/#{puppet_collection}/x86_64", "puppet-agent-#{puppet_agent_version}-1.el7.x86_64.rpm"]
                  }
      platforms.each do |p, v|
        it "accomodates platform #{p} without erroring" do
          platform = Beaker::Platform.new(p)
          @opts = {'platform' => platform}
          allow( instance ).to receive(:link_exists?).and_return(true)
          expect( instance.puppet_agent_dev_package_info( puppet_collection, puppet_agent_version, { :download_url => 'http://trust.me' } )).to eq(v)
        end
      end
    end

    describe '#upgrade_package' do
      PlatformHelpers::DEBIANPLATFORMS.each do |platform|
        it "calls the correct apt-get incantation for #{platform}" do
          @opts = {'platform' => platform}
          expect( Beaker::Command ).to receive(:new).with("apt-get install -o Dpkg::Options::='--force-confold'  -y --force-yes pkg", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
          expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
          expect(instance.upgrade_package('pkg')).to be == "hello"
        end
      end
    end
    context "install_package_with_rpm" do

      it "accepts a package as a single argument" do
        @opts = {'platform' => 'el-is-me'}
        pkg = 'redhat_package'
        expect( Beaker::Command ).to receive(:new).with("rpm  -Uvh #{pkg} ", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
        expect( instance ).to receive(:exec).with('', {}).and_return(generate_result("hello", {:exit_code => 0}))
        expect( instance.install_package_with_rpm(pkg) ).to be == "hello"
      end

      it "accepts a package and additional options" do
        @opts = {'platform' => 'el-is-me'}
        pkg = 'redhat_package'
        cmdline_args = '--foo'
        expect( Beaker::Command ).to receive(:new).with("rpm #{cmdline_args} -Uvh #{pkg} ", [], {:prepend_cmds=>nil, :cmdexe=>false}).and_return('')
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
              allow( instance ).to receive( :exec )
              if supported_version
                if version == 10
                  allow( instance ).to receive( :noask_file_text )
                  allow( instance ).to receive( :create_remote_file )
                  allow( instance ).to receive( :execute ).with('/opt/csw/bin/pkgutil -y -i pkgutil')
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
            allow( instance ).to receive( :exec )
            expect( instance ).to receive( :noask_file_text )
            expect( instance ).to receive( :create_remote_file )
            instance.pe_puppet_agent_promoted_package_install('', '', '', '', {})
          end

          it 'calls the correct install command' do
            allow( instance ).to receive( :noask_file_text )
            allow( instance ).to receive( :create_remote_file )
            # a number of `execute` calls before the one we're looking for
            allow( instance ).to receive( :execute )
            allow( instance ).to receive( :exec )
            # actual gunzip call to
            expect( Beaker::Command ).to receive( :new ).with( /^gunzip\ \-c\ / )
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
            allow( instance ).to receive( :execute )
            allow( instance ).to receive( :exec )
            expect( Beaker::Command ).to receive( :new ).with( /^pkg\ install\ \-g / )
            instance.pe_puppet_agent_promoted_package_install(
              'oh_cp_base', 'oh_cp_dl', 'oh_cp_fl', 'dl_fl', {}
            )
          end
        end
      end
    end

    describe '#install_local_package' do
      let( :platform      ) { @platform || 'fedora' }
      let( :version       ) { @version  || 6        }
      let( :platform_mock ) {
        mock = Object.new
        allow( mock ).to receive( :to_array ) { [platform, version, '', ''] }
        mock
      }

      before :each do
        allow( instance ).to receive( :[] ).with( 'platform' ) { platform_mock }
      end

      it 'Fedora 22-29: uses dnf' do
        (22...29).each do |version|
          @version = version
          package_file = 'test_123.yay'
          expect( instance ).to receive( :execute ).with( /^dnf.*#{package_file}$/ )
          instance.install_local_package( package_file )
        end
      end

      it 'Fedora 21 & 30: uses yum' do
        package_file = 'testing_456.yay'
        platform_mock = Object.new
        [21, 30].each do |version|
          @version = version
          expect( instance ).to receive( :execute ).with( /^yum.*#{package_file}$/ )
          instance.install_local_package( package_file )
        end
      end

      it 'Centos & EL: uses yum' do
        package_file = 'testing_789.yay'
        ['centos', 'el'].each do |platform|
          @platform = platform
          expect( instance ).to receive( :execute ).with( /^yum.*#{package_file}$/ )
          instance.install_local_package( package_file )
        end
      end

      it 'Debian, Ubuntu, Cumulus: uses dpkg' do
        package_file = 'testing_012.yay'
        ['debian', 'ubuntu', 'cumulus'].each do |platform|
          @platform = platform
          expect( instance ).to receive( :execute ).with( /^dpkg.*#{package_file}$/ )
          expect( instance ).to receive( :execute ).with( 'apt-get update' )
          instance.install_local_package( package_file )
        end
      end

      it 'Solaris: calls solaris-specific install method' do
        package_file = 'testing_345.yay'
        @platform = 'solaris'
        expect( instance ).to receive( :solaris_install_local_package ).with( package_file, anything )
        instance.install_local_package( package_file )
      end

      it 'OSX: calls host.install_package' do
        package_file = 'testing_678.yay'
        @platform = 'osx'
        expect( instance ).to receive( :install_package ).with( package_file )
        instance.install_local_package( package_file )
      end
    end

    describe '#uncompress_local_tarball' do
      let( :platform      ) { @platform || 'fedora' }
      let( :version       ) { @version  || 6        }
      let( :tar_file      ) { 'test.tar.gz'         }
      let( :base_dir      ) { '/base/dir/fake'      }
      let( :download_file ) { 'download_file.txt'   }
      let( :platform_mock ) {
        mock = Object.new
        allow( mock ).to receive( :to_array ) { [platform, version, '', ''] }
        mock
      }

      before :each do
        allow( instance ).to receive( :[] ).with( 'platform' ) { platform_mock }
      end

      it 'rejects unsupported platforms' do
        @platform = 'huawei'
        expect {
          instance.uncompress_local_tarball( tar_file, base_dir, download_file )
        }.to raise_error(
          /^Platform #{platform} .* not supported .* uncompress_local_tarball$/
        )
      end

      it 'untars the file given' do
        @platform = 'sles'
        expect( instance ).to receive( :execute ).with(
          /^tar .* #{tar_file} .* #{base_dir}$/
        )
        instance.uncompress_local_tarball( tar_file, base_dir, download_file )
      end

      context 'on solaris' do

        before :each do
          @platform = 'solaris'
        end

        it 'rejects unsupported versions' do
          @version = '12'
          expect {
            instance.uncompress_local_tarball( tar_file, base_dir, download_file )
          }.to raise_error(
            /^Solaris #{version} .* not supported .* uncompress_local_tarball$/
          )
        end

        it 'v10: gunzips before untaring' do
          @version = '10'
          expect( instance ).to receive( :execute ).with( /^gunzip #{tar_file}$/ )
          expect( instance ).to receive( :execute ).with( /^tar .* #{download_file}$/ )
          instance.uncompress_local_tarball( tar_file, base_dir, download_file )
        end

        it 'v11: untars only' do
          @version = '11'
          expect( instance ).to receive( :execute ).with( /^tar .* #{tar_file}$/ )
          instance.uncompress_local_tarball( tar_file, base_dir, download_file )
        end

      end
    end
  end
end

