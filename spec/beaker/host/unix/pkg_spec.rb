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
        # noop
      end
    end

    let(:opts)     { @opts || {} }
    let(:logger)   { double('logger').as_null_object }
    let(:instance) { UnixPkgTest.new(opts, logger) }

    context "check_for_package" do
      it "checks correctly on sles" do
        @opts = { 'platform' => 'sles-is-me' }
        pkg = 'sles_package'
        expect(Beaker::Command).to receive(:new).with(/^rpmkeys.*nightlies.puppetlabs.com.*/, anything, anything).and_return('').ordered.once
        expect(Beaker::Command).to receive(:new).with("zypper --gpg-auto-import-keys se -i --match-exact #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('').ordered.once
        expect(instance).to receive(:exec).with('', { :accept_all_exit_codes => true }).and_return(generate_result("hello", { :exit_code => 0 })).twice
        expect(instance.check_for_package(pkg)).to be === true
      end

      it "checks correctly on opensuse" do
        @opts = { 'platform' => 'opensuse-is-me' }
        pkg = 'sles_package'
        expect(Beaker::Command).to receive(:new).with(/^rpmkeys.*nightlies.puppetlabs.com.*/, anything, anything).and_return('').ordered.once
        expect(Beaker::Command).to receive(:new).with("zypper --gpg-auto-import-keys se -i --match-exact #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('').ordered.once
        expect(instance).to receive(:exec).with('', { :accept_all_exit_codes => true }).and_return(generate_result("hello", { :exit_code => 0 })).twice
        expect(instance.check_for_package(pkg)).to be === true
      end

      it "checks correctly on fedora" do
        @opts = { 'platform' => 'fedora-is-me' }
        pkg = 'fedora_package'
        expect(Beaker::Command).to receive(:new).with("rpm -q #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', { :accept_all_exit_codes => true }).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.check_for_package(pkg)).to be === true
      end

      %w[amazon centos redhat].each do |platform|
        it "checks correctly on #{platform}" do
          @opts = { 'platform' => "#{platform}-is-me" }
          pkg = "#{platform}_package"
          expect(Beaker::Command).to receive(:new).with("rpm -q #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
          expect(instance).to receive(:exec).with('', { :accept_all_exit_codes => true }).and_return(generate_result("hello", { :exit_code => 0 }))
          expect(instance.check_for_package(pkg)).to be === true
        end
      end

      it "checks correctly on EOS" do
        @opts = { 'platform' => 'eos-is-me' }
        pkg = 'eos-package'
        expect(Beaker::Command).to receive(:new).with("rpm -q #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', { :accept_all_exit_codes => true }).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.check_for_package(pkg)).to be === true
      end

      it "checks correctly on el-" do
        @opts = { 'platform' => 'el-is-me' }
        pkg = 'el_package'
        expect(Beaker::Command).to receive(:new).with("rpm -q #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', { :accept_all_exit_codes => true }).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.check_for_package(pkg)).to be === true
      end

      it "checks correctly on huaweios" do
        @opts = { 'platform' => 'huaweios-is-me' }
        pkg = 'debian_package'
        expect(Beaker::Command).to receive(:new).with("dpkg -s #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', { :accept_all_exit_codes => true }).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.check_for_package(pkg)).to be === true
      end

      it "checks correctly on debian" do
        @opts = { 'platform' => 'debian-is-me' }
        pkg = 'debian_package'
        expect(Beaker::Command).to receive(:new).with("dpkg -s #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', { :accept_all_exit_codes => true }).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.check_for_package(pkg)).to be === true
      end

      it "checks correctly on ubuntu" do
        @opts = { 'platform' => 'ubuntu-is-me' }
        pkg = 'ubuntu_package'
        expect(Beaker::Command).to receive(:new).with("dpkg -s #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', { :accept_all_exit_codes => true }).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.check_for_package(pkg)).to be === true
      end

      it "checks correctly on solaris-11" do
        @opts = { 'platform' => 'solaris-11-is-me' }
        pkg = 'solaris-11_package'
        expect(Beaker::Command).to receive(:new).with("pkg info #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', { :accept_all_exit_codes => true }).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.check_for_package(pkg)).to be === true
      end

      it "checks correctly on solaris-10" do
        @opts = { 'platform' => 'solaris-10-is-me' }
        pkg = 'solaris-10_package'
        expect(Beaker::Command).to receive(:new).with("pkginfo #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', { :accept_all_exit_codes => true }).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.check_for_package(pkg)).to be === true
      end

      it "checks correctly on archlinux" do
        @opts = { 'platform' => 'archlinux-is-me' }
        pkg = 'archlinux_package'
        expect(Beaker::Command).to receive(:new).with("pacman -Q #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', { :accept_all_exit_codes => true }).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.check_for_package(pkg)).to be === true
      end

      it "returns false for el-4" do
        @opts = { 'platform' => 'el-4-is-me' }
        pkg = 'el-4_package'
        expect(instance.check_for_package(pkg)).to be === false
      end

      it "raises on unknown platform" do
        @opts = { 'platform' => 'nope-is-me' }
        pkg = 'nope_package'
        expect { instance.check_for_package(pkg) }.to raise_error
      end
    end

    describe '#update_apt_if_needed' do
      PlatformHelpers::DEBIANPLATFORMS.each do |platform|
        it "calls update for #{platform}" do
          @opts = { 'platform' => platform }
          instance.instance_variable_set(:@apt_needs_update, true)
          expect(instance).to receive('execute').with("apt-get update")
          expect { instance.update_apt_if_needed }.not_to raise_error
        end
      end
    end

    context "install_package" do
      PlatformHelpers::DEBIANPLATFORMS.each do |platform|
        it "uses apt-get for #{platform}" do
          @opts = { 'platform' => platform }
          pkg = 'pkg'
          expect(Beaker::Command).to receive(:new).with("apt-get install --force-yes  -y #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
          expect(instance).to receive(:exec).with('', {}).and_return(generate_result("hello", { :exit_code => 0 }))
          expect(instance.install_package(pkg)).to eq "hello"
        end
      end

      it "uses dnf on fedora" do
        @opts = { 'platform' => "fedora-is-me" }
        pkg = 'fedora_package'
        expect(Beaker::Command).to receive(:new).with("dnf -y  install #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', {}).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.install_package(pkg)).to eq "hello"
      end

      it "uses dnf on amazon-2023" do
        @opts = { 'platform' => "amazon-2023-is-me" }
        pkg = 'amazon_package'
        expect(Beaker::Command).to receive(:new).with("dnf -y  install #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', {}).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.install_package(pkg)).to eq "hello"
      end

      it "uses pacman on archlinux" do
        @opts = { 'platform' => 'archlinux-is-me' }
        pkg = 'archlinux_package'
        expect(Beaker::Command).to receive(:new).with("pacman -S --noconfirm  #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', {}).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.install_package(pkg)).to eq "hello"
      end
    end

    describe '#uninstall_package' do
      PlatformHelpers::DEBIANPLATFORMS.each do |platform|
        it "calls pkg uninstall for #{platform}" do
          @opts = { 'platform' => platform }
          expect(Beaker::Command).to receive(:new).with("apt-get purge  -y pkg", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
          expect(instance).to receive(:exec).with('', {}).and_return(generate_result("hello", { :exit_code => 0 }))
          expect(instance.uninstall_package('pkg')).to eq "hello"
        end

        it "uses dnf on fedora" do
          @opts = { 'platform' => "fedora-is-me" }
          pkg = 'fedora_package'
          expect(Beaker::Command).to receive(:new).with("dnf -y  remove #{pkg}", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
          expect(instance).to receive(:exec).with('', {}).and_return(generate_result("hello", { :exit_code => 0 }))
          expect(instance.uninstall_package(pkg)).to eq "hello"
        end
      end
    end

    describe '#upgrade_package' do
      PlatformHelpers::DEBIANPLATFORMS.each do |platform|
        it "calls the correct apt-get incantation for #{platform}" do
          @opts = { 'platform' => platform }
          expect(Beaker::Command).to receive(:new).with("apt-get install -o Dpkg::Options::='--force-confold'  -y --force-yes pkg", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
          expect(instance).to receive(:exec).with('', {}).and_return(generate_result("hello", { :exit_code => 0 }))
          expect(instance.upgrade_package('pkg')).to eq "hello"
        end
      end
    end

    context "install_package_with_rpm" do
      it "accepts a package as a single argument" do
        @opts = { 'platform' => 'el-is-me' }
        pkg = 'redhat_package'
        expect(Beaker::Command).to receive(:new).with("rpm  -Uvh #{pkg} ", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', {}).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.install_package_with_rpm(pkg)).to eq "hello"
      end

      it "accepts a package and additional options" do
        @opts = { 'platform' => 'el-is-me' }
        pkg = 'redhat_package'
        cmdline_args = '--foo'
        expect(Beaker::Command).to receive(:new).with("rpm #{cmdline_args} -Uvh #{pkg} ", [], { :prepend_cmds => nil, :cmdexe => false }).and_return('')
        expect(instance).to receive(:exec).with('', {}).and_return(generate_result("hello", { :exit_code => 0 }))
        expect(instance.install_package_with_rpm(pkg, cmdline_args)).to eq "hello"
      end
    end

    context 'extract_rpm_proxy_options' do
      ['http://myproxy.com:3128/',
       'https://myproxy.com:3128/',
       'https://myproxy.com:3128',
       'http://myproxy.com:3128',].each do |url|
        it "correctly extracts rpm proxy options for #{url}" do
          expect(instance.extract_rpm_proxy_options(url)).to eq '--httpproxy myproxy.com --httpport 3128'
        end
      end

      url = 'http:/myproxy.com:3128'
      it "fails to extract rpm proxy options for #{url}" do
        expect do
          instance.extract_rpm_proxy_options(url)
        end.to raise_error(RuntimeError, /Cannot extract host and port/)
      end
    end

    describe '#install_local_package' do
      let(:platform) { @platform || 'fedora' }
      let(:version) { @version || 6 }

      before do
        allow(instance).to receive(:[]).with('platform') { Beaker::Platform.new("#{platform}-#{version}-x86_64") }
      end

      it 'amazon-2023: uses dnf' do
        @platform = platform
        @version = '2023'
        package_file = 'test_123.yay'
        expect(instance).to receive(:execute).with(/^dnf.*#{package_file}$/)
        instance.install_local_package(package_file)
      end

      it 'Fedora 22-39: uses dnf' do
        (22...39).each do |version|
          @version = version
          package_file = 'test_123.yay'
          expect(instance).to receive(:execute).with(/^dnf.*#{package_file}$/)
          instance.install_local_package(package_file)
        end
      end

      it 'Fedora 21 uses yum' do
        package_file = 'testing_456.yay'
        [21].each do |version|
          @version = version
          expect(instance).to receive(:execute).with(/^yum.*#{package_file}$/)
          instance.install_local_package(package_file)
        end
      end

      it 'Centos & EL: uses yum' do
        package_file = 'testing_789.yay'
        %w[centos redhat].each do |platform|
          @platform = platform
          expect(instance).to receive(:execute).with(/^yum.*#{package_file}$/)
          instance.install_local_package(package_file)
        end
      end

      it 'Debian, Ubuntu: uses dpkg' do
        package_file = 'testing_012.yay'
        %w[debian ubuntu].each do |platform|
          @platform = platform
          expect(instance).to receive(:execute).with(/^dpkg.*#{package_file}$/)
          expect(instance).to receive(:execute).with('apt-get update')
          instance.install_local_package(package_file)
        end
      end

      it 'Solaris: calls solaris-specific install method' do
        package_file = 'testing_345.yay'
        @platform = 'solaris'
        expect(instance).to receive(:solaris_install_local_package).with(package_file, anything)
        instance.install_local_package(package_file)
      end

      it 'OSX: calls host.install_package' do
        package_file = 'testing_678.yay'
        @platform = 'osx'
        expect(instance).to receive(:install_package).with(package_file)
        instance.install_local_package(package_file)
      end
    end

    describe '#uncompress_local_tarball' do
      let(:platform) { @platform || 'fedora' }
      let(:version) { @version || 6 }
      let(:tar_file) { 'test.tar.gz'         }
      let(:base_dir) { '/base/dir/fake'      }
      let(:download_file) { 'download_file.txt' }

      before do
        allow(instance).to receive(:[]).with('platform') { Beaker::Platform.new("#{platform}-#{version}-x86_64") }
      end

      it 'rejects unsupported platforms' do
        @platform = 'cisco_nexus'
        expect do
          instance.uncompress_local_tarball(tar_file, base_dir, download_file)
        end.to raise_error(
          /^Platform #{platform} .* not supported .* uncompress_local_tarball$/,
        )
      end

      it 'untars the file given' do
        @platform = 'sles'
        expect(instance).to receive(:execute).with(
          /^tar .* #{tar_file} .* #{base_dir}$/,
        )
        instance.uncompress_local_tarball(tar_file, base_dir, download_file)
      end

      it 'untars the file given' do
        @platform = 'opensuse'
        expect(instance).to receive(:execute).with(
          /^tar .* #{tar_file} .* #{base_dir}$/,
        )
        instance.uncompress_local_tarball(tar_file, base_dir, download_file)
      end

      context 'on solaris' do
        before do
          @platform = 'solaris'
        end

        it 'rejects unsupported versions' do
          @version = '12'
          expect do
            instance.uncompress_local_tarball(tar_file, base_dir, download_file)
          end.to raise_error(
            /^Solaris #{version} .* not supported .* uncompress_local_tarball$/,
          )
        end

        it 'v10: gunzips before untaring' do
          @version = '10'
          expect(instance).to receive(:execute).with(/^gunzip #{tar_file}$/)
          expect(instance).to receive(:execute).with(/^tar .* #{download_file}$/)
          instance.uncompress_local_tarball(tar_file, base_dir, download_file)
        end

        it 'v11: untars only' do
          @version = '11'
          expect(instance).to receive(:execute).with(/^tar .* #{tar_file}$/)
          instance.uncompress_local_tarball(tar_file, base_dir, download_file)
        end
      end
    end
  end
end
