require 'spec_helper'

describe Beaker do
  let(:options)        { make_opts.merge({ 'logger' => double.as_null_object }) }
  let(:ntpserver_set)  { "ntp_server_set" }
  let(:options_ntp)    { make_opts.merge({ 'ntp_server' => ntpserver_set }) }
  let(:ntpserver)      { Beaker::HostPrebuiltSteps::NTPSERVER }
  let(:sync_cmd)       { Beaker::HostPrebuiltSteps::ROOT_KEYS_SYNC_CMD }
  let(:dummy_class) { Class.new { include Beaker::HostPrebuiltSteps } }

  shared_examples 'enables_root_login' do |platform, commands, non_cygwin|
    subject { dummy_class.new }

    it "can enable root login on #{platform}" do
      hosts = make_hosts({ :platform => platform, :is_cygwin => non_cygwin })

      expect(Beaker::Command).to receive(:new).exactly(0).times if commands.empty?

      commands.each do |command|
        expect(Beaker::Command).to receive(:new).with(command).exactly(3).times
      end

      subject.enable_root_login(hosts, options)
    end
  end

  # Non-cygwin Windows
  it_behaves_like 'enables_root_login', 'windows-11-64', [], false

  # cygwin Windows
  it_behaves_like 'enables_root_login', 'windows-11-64', [
    "sed -ri 's/^#?PermitRootLogin /PermitRootLogin yes/' /etc/sshd_config",
  ], true

  # FreeBSD
  it_behaves_like 'enables_root_login', 'freebsd-14-64', [
    "sudo sed -i -e 's/#PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config",
    "sudo /etc/rc.d/sshd restart",
  ], true

  it_behaves_like 'enables_root_login', 'osx-10.10-64', [
    "sudo sed -i '' 's/#PermitRootLogin yes/PermitRootLogin Yes/g' /etc/sshd_config",
    "sudo sed -i '' 's/#PermitRootLogin no/PermitRootLogin Yes/g' /etc/sshd_config",
  ]

  it_behaves_like 'enables_root_login', 'osx-10.11-64', [
    "sudo sed -i '' 's/#PermitRootLogin yes/PermitRootLogin Yes/g' /private/etc/ssh/sshd_config",
    "sudo sed -i '' 's/#PermitRootLogin no/PermitRootLogin Yes/g' /private/etc/ssh/sshd_config",
  ]

  it_behaves_like 'enables_root_login', 'osx-10.12-64', [
    "sudo sed -i '' 's/#PermitRootLogin yes/PermitRootLogin Yes/g' /private/etc/ssh/sshd_config",
    "sudo sed -i '' 's/#PermitRootLogin no/PermitRootLogin Yes/g' /private/etc/ssh/sshd_config",
  ]

  it_behaves_like 'enables_root_login', 'osx-10.13-64', [
    "sudo sed -i '' 's/#PermitRootLogin yes/PermitRootLogin Yes/g' /private/etc/ssh/sshd_config",
    "sudo sed -i '' 's/#PermitRootLogin no/PermitRootLogin Yes/g' /private/etc/ssh/sshd_config",
  ]

  # Solaris
  it_behaves_like 'enables_root_login', 'solaris-10-64', [
    "sudo -E svcadm restart network/ssh",
    "sudo gsed -i -e 's/#PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config",
  ], true

  it_behaves_like 'enables_root_login', 'solaris-11-64', [
    "sudo -E svcadm restart network/ssh",
    "sudo gsed -i -e 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config",
    "if grep \"root::::type=role\" /etc/user_attr; then sudo rolemod -K type=normal root; else echo \"root user already type=normal\"; fi",
  ], true

  it_behaves_like 'enables_root_login', 'amazon-2023-64', [
    "sudo su -c \"sed -ri 's/^#?PermitRootLogin no|^#?PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config\"",
    "sudo -E systemctl restart sshd.service",
  ]

  %w[debian-12-64 ubuntu-2204-64].each do |deb_like|
    it_behaves_like 'enables_root_login', deb_like, [
      "sudo su -c \"sed -ri 's/^#?PermitRootLogin no|^#?PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config\"",
      "sudo su -c \"service ssh restart\"",
    ]
  end

  ['centos-9-64', 'el-9-64', 'redhat-9-64', 'fedora-39-64'].each do |redhat_like|
    it_behaves_like 'enables_root_login', redhat_like, [
      "sudo su -c \"sed -ri 's/^#?PermitRootLogin no|^#?PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config\"",
      "sudo -E systemctl restart sshd.service",
    ]
  end

  context 'timesync' do
    subject { dummy_class.new }

    it "can sync time on el-7 hosts" do
      hosts = make_hosts({ :platform => 'el-7-64' })

      expect(Beaker::Command).to receive(:new).with("ntpdate -u -t 20 #{ntpserver}").exactly(3).times

      subject.timesync(hosts, options)
    end

    it "can retry on failure on unix hosts" do
      hosts = make_hosts({ :platform => 'el-7-64', :exit_code => [1, 0] })
      allow(subject).to receive(:sleep).and_return(true)

      expect(Beaker::Command).to receive(:new).with("ntpdate -u -t 20 #{ntpserver}").exactly(6).times

      subject.timesync(hosts, options)
    end

    it "eventually gives up and raises an error when unix hosts can't be synched" do
      hosts = make_hosts({ :platform => 'el-7-64', :exit_code => 1 })
      allow(subject).to receive(:sleep).and_return(true)

      expect(Beaker::Command).to receive(:new).with("ntpdate -u -t 20 #{ntpserver}").exactly(5).times

      expect { subject.timesync(hosts, options) }.to raise_error(/NTP date was not successful after/)
    end

    it "can sync time on windows hosts" do
      hosts = make_hosts({ :platform => 'windows-11-64' })

      expect(Beaker::Command).to receive(:new).with("w32tm /register").exactly(3).times
      expect(Beaker::Command).to receive(:new).with("net start w32time").exactly(3).times
      expect(Beaker::Command).to receive(:new).with("w32tm /config /manualpeerlist:#{ntpserver} /syncfromflags:manual /update").exactly(3).times
      expect(Beaker::Command).to receive(:new).with("w32tm /resync").exactly(3).times

      subject.timesync(hosts, options)
    end

    it "can sync time on Sles hosts" do
      hosts = make_hosts({ :platform => 'sles-13.1-x64' })

      expect(Beaker::Command).to receive(:new).with("sntp #{ntpserver}").exactly(3).times

      subject.timesync(hosts, options)
    end

    it "can sync time on amazon2023 hosts" do
      hosts = make_hosts(:platform => 'amazon-2023-x86_64')
      expect(Beaker::Command).to receive(:new)
        .with("chronyc add server #{ntpserver} prefer trust;chronyc makestep;chronyc burst 1/2")
        .exactly(3)
        .times
      subject.timesync(hosts, options)
    end

    it "can sync time on RHEL8 hosts" do
      hosts = make_hosts(:platform => 'el-8-x86_x64')
      expect(Beaker::Command).to receive(:new)
        .with("chronyc add server #{ntpserver} prefer trust;chronyc makestep;chronyc burst 1/2")
        .exactly(3)
        .times
      subject.timesync(hosts, options)
    end

    it "can sync time on Fedora hosts" do
      hosts = make_hosts(:platform => 'fedora-32-x86_64')
      expect(Beaker::Command).to receive(:new)
        .with("chronyc add server #{ntpserver} prefer trust;chronyc makestep;chronyc burst 1/2")
        .exactly(3)
        .times
      subject.timesync(hosts, options)
    end

    it "can set time server on el-7 hosts" do
      hosts = make_hosts({ :platform => 'el-7-64' })

      expect(Beaker::Command).to receive(:new).with("ntpdate -u -t 20 #{ntpserver_set}").exactly(3).times

      subject.timesync(hosts, options_ntp)
    end

    it "can set time server on windows hosts" do
      hosts = make_hosts({ :platform => 'windows-11-64' })

      expect(Beaker::Command).to receive(:new).with("w32tm /register").exactly(3).times
      expect(Beaker::Command).to receive(:new).with("net start w32time").exactly(3).times
      expect(Beaker::Command).to receive(:new).with("w32tm /config /manualpeerlist:#{ntpserver_set} /syncfromflags:manual /update").exactly(3).times
      expect(Beaker::Command).to receive(:new).with("w32tm /resync").exactly(3).times

      subject.timesync(hosts, options_ntp)
    end

    it "can set time server on Sles hosts" do
      hosts = make_hosts({ :platform => 'sles-13.1-x64' })

      expect(Beaker::Command).to receive(:new).with("sntp #{ntpserver_set}").exactly(3).times

      subject.timesync(hosts, options_ntp)
    end

    it "can set time server on RHEL8 hosts" do
      hosts = make_hosts(:platform => 'el-8-x86_x64')
      expect(Beaker::Command).to receive(:new)
        .with("chronyc add server #{ntpserver_set} prefer trust;chronyc makestep;chronyc burst 1/2")
        .exactly(3)
        .times
      subject.timesync(hosts, options_ntp)
    end
  end

  context "apt_get_update" do
    subject { dummy_class.new }

    it "can perform apt-get on ubuntu hosts" do
      host = make_host('testhost', { :platform => 'ubuntu-2204-64' })

      expect(Beaker::Command).to receive(:new).with("apt-get update -qq").once

      subject.apt_get_update(host)
    end

    it "can perform apt-get on debian hosts" do
      host = make_host('testhost', { :platform => 'debian-12-64' })

      expect(Beaker::Command).to receive(:new).with("apt-get update -qq").once

      subject.apt_get_update(host)
    end

    it "does nothing on non debian/ubuntu hosts" do
      host = make_host('testhost', { :platform => 'windows-11-64' })

      expect(Beaker::Command).not_to receive(:new)

      subject.apt_get_update(host)
    end
  end

  context "copy_file_to_remote" do
    subject { dummy_class.new }

    it "can copy a file to a remote host" do
      content = "this is the content"
      tempfilepath = "/path/to/tempfile"
      filepath = "/path/to/file"
      host = make_host('testhost', { :platform => 'windows-11-64' })
      tempfile = double('tempfile')
      allow(tempfile).to receive(:path).and_return(tempfilepath)
      allow(Tempfile).to receive(:open).and_yield(tempfile)
      file = double('file')
      allow(File).to receive(:open).and_yield(file)

      expect(file).to receive(:puts).with(content).once
      expect(host).to receive(:do_scp_to).with(tempfilepath, filepath, subject.instance_variable_get(:@options)).once

      subject.copy_file_to_remote(host, filepath, content)
    end
  end

  context "sync_root_keys" do
    subject { dummy_class.new }

    it "can sync keys on a solaris host" do
      host = make_host('host', { 'platform' => 'solaris-11-64' })

      expect(Beaker::Command).to receive(:new).with(sync_cmd % "bash").once

      subject.sync_root_keys(host, options)
    end

    it "can sync keys on a non-solaris host" do
      host = make_host('host', { 'platform' => 'el-9-64' })

      expect(Beaker::Command).to receive(:new).with(sync_cmd % "env PATH=\"/usr/gnu/bin:$PATH\" bash").once

      subject.sync_root_keys(host, options)
    end
  end

  context "validate_host" do
    subject { dummy_class.new }

    it "can validate el-9 hosts" do
      host = make_host('host', { :platform => 'el-9-64' })

      ['curl-minimal', 'iputils'].each do |pkg|
        expect(host).to receive(:check_for_package).with(pkg).once.and_return(false)
        expect(host).to receive(:install_package).with(pkg).once
      end

      subject.validate_host(host, options)
    end

    it "can validate windows hosts" do
      host = make_host('host', { :platform => 'windows-11-64', :is_cygwin => true })
      allow(host).to receive(:cygwin_installed?).and_return(true)

      ['curl'].each do |pkg|
        expect(host).to receive(:check_for_package).with(pkg).once.and_return(false)
        expect(host).to receive(:install_package).with(pkg).once
      end

      subject.validate_host(host, options)
    end

    it "can validate SLES hosts" do
      host = make_host('host', { :platform => 'sles-13.1-x86_64' })

      ['curl'].each do |pkg|
        expect(host).to receive(:check_for_package).with(pkg).once.and_return(false)
        expect(host).to receive(:install_package).with(pkg).once
      end

      subject.validate_host(host, options)
    end

    it "can validate opensuse hosts" do
      host = make_host('host', { :platform => 'opensuse-15-x86_x64' })

      ['curl'].each do |pkg|
        expect(host).to receive(:check_for_package).with(pkg).once.and_return(false)
        expect(host).to receive(:install_package).with(pkg).once
      end

      subject.validate_host(host, options)
    end

    it "can validate RHEL8 hosts" do
      host = make_host('host', { :platform => 'el-8-64' })

      ['curl-minimal', 'iputils'].each do |pkg|
        expect(host).to receive(:check_for_package).with(pkg).once.and_return(false)
        expect(host).to receive(:install_package).with(pkg).once
      end

      subject.validate_host(host, options)
    end

    it "can validate Fedora hosts" do
      host = make_host('host', { :platform => 'fedora-32-x86_64' })

      ['curl-minimal', 'iputils'].each do |pkg|
        expect(host).to receive(:check_for_package).with(pkg).once.and_return(false)
        expect(host).to receive(:install_package).with(pkg).once
      end

      subject.validate_host(host, options)
    end

    it "can validate Amazon hosts" do
      host = make_host('host', { :platform => 'amazon-2023-x86_64' })

      ['curl-minimal', 'iputils'].each do |pkg|
        expect(host).to receive(:check_for_package).with(pkg).once.and_return(false)
        expect(host).to receive(:install_package).with(pkg).once
      end

      subject.validate_host(host, options)
    end
  end

  context 'get_domain_name' do
    subject { dummy_class.new }

    shared_examples 'find domain name' do
      it "finds the domain name" do
        cmd = instance_double(Beaker::Command)
        expect(Beaker::Command).to receive(:new).with(cat).once.and_return(cmd)
        result = instance_double(Beaker::Result)
        expect(host).to receive(:exec).with(cmd).and_return(result)
        expect(result).to receive(:stdout).and_return(stdout)
        expect(subject.get_domain_name(host)).to be === "labs.lan"
      end
    end

    context "on windows" do
      let(:host) do
        make_host('name', {
                    :platform => 'windows-11-64',
                    :is_cygwin => cygwin,
                  })
      end

      let(:stdout) { "domain labs.lan d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" }

      context "with cygwin" do
        let(:cygwin) { true }
        let(:cat) { "cat /cygdrive/c/Windows/System32/drivers/etc/hosts" }

        include_examples 'find domain name'
      end

      context "without cygwin" do
        let(:cygwin) { false }
        let(:cat) { 'type C:\Windows\System32\drivers\etc\hosts' }

        include_examples 'find domain name'
      end
    end

    %w[amazon-2023-64 centos-9-64 redhat-9-64].each do |platform|
      context "on platform '#{platform}'" do
        let(:host) { make_host('name', { :platform => platform }) }
        let(:cat) { "cat /etc/resolv.conf" }

        context "with a domain entry" do
          let(:stdout) { "domain labs.lan d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" }

          include_examples 'find domain name'
        end

        context "with a search entry" do
          let(:stdout) { "search labs.lan d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" }

          include_examples 'find domain name'
        end

        context "with a both a domain and a search entry" do
          let(:stdout) { "domain labs.lan\nsearch d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" }

          include_examples 'find domain name'
        end

        context "with a both a domain and a search entry, the search entry first" do
          let(:stdout) { "search foo.example.net\ndomain labs.lan d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" }

          include_examples 'find domain name'
        end
      end
    end
  end

  context "set_etc_hosts" do
    subject { dummy_class.new }

    it "can set the /etc/hosts string on a host" do
      host = make_host('name', {})
      etc_hosts = "127.0.0.1  localhost\n192.168.2.130 pe-ubuntu-lucid\n192.168.2.128 pe-centos6\n192.168.2.131 pe-debian6"

      expect(Beaker::Command).to receive(:new).with("echo '#{etc_hosts}' >> /etc/hosts").once
      expect(host).to receive(:exec).once

      subject.set_etc_hosts(host, etc_hosts)
    end
  end

  context "copy_ssh_to_root" do
    subject { dummy_class.new }

    it "can copy ssh to root in windows hosts with no cygwin" do
      host = make_host('testhost', { :platform => 'windows-11-64', :is_cygwin => false })
      expect(Beaker::Command).to receive(:new).with("if exist .ssh (xcopy .ssh C:\\Users\\Administrator\\.ssh /s /e /y /i)").once

      subject.copy_ssh_to_root(host, options)
    end
  end

  context "package_proxy" do
    subject { dummy_class.new }

    proxyurl = "http://192.168.2.100:3128"

    it "can set proxy config on a debian/ubuntu host" do
      host = make_host('name', { :platform => 'debian-12-64' })

      expect(Beaker::Command).to receive(:new).with("echo 'Acquire::http::Proxy \"#{proxyurl}/\";' >> /etc/apt/apt.conf.d/10proxy").once
      expect(host).to receive(:exec).once

      subject.package_proxy(host, options.merge({ 'package_proxy' => proxyurl }))
    end

    %w[amazon-2023-64 el-9-64].each do |platform|
      it "can set proxy config on a '#{platform}' host" do
        host = make_host('name', { :platform => platform })

        expect(Beaker::Command).to receive(:new).with("echo 'proxy=#{proxyurl}/' >> /etc/yum.conf").once
        expect(host).to receive(:exec).once

        subject.package_proxy(host, options.merge({ 'package_proxy' => proxyurl }))
      end
    end
  end

  context "set_env" do
    subject { dummy_class.new }

    it "sets user ssh environment on an OS X 10.10 host" do
      test_host_ssh_calls('osx-10.10-64')
    end

    it "sets user ssh environment on an OS X 10.11 host" do
      test_host_ssh_calls('osx-10.11-64')
    end

    it "sets user ssh environment on an OS X 10.12 host" do
      test_host_ssh_calls('osx-10.12-64')
    end

    it "sets user ssh environment on an OS X 10.13 host" do
      test_host_ssh_calls('osx-10.13-64')
    end

    it "sets user ssh environment on an ssh-based linux host" do
      test_host_ssh_calls('ubuntu-2204-64')
    end

    it "sets user ssh environment on an sles host" do
      test_host_ssh_calls('sles-15-64')
    end

    it "sets user ssh environment on a solaris host" do
      test_host_ssh_calls('solaris-11-64')
    end

    it "sets user ssh environment on an aix host" do
      test_host_ssh_calls('aix-7.2-power')
    end

    it "sets user ssh environment on a FreeBSD host" do
      test_host_ssh_calls('freebsd-14-64')
    end

    it "sets user ssh environment on a windows host" do
      test_host_ssh_calls('windows-11-64')
    end

    def test_host_ssh_calls(platform_name)
      host = make_host('name', {
                         :platform => platform_name,
                         :ssh_env_file => 'ssh_env_file',
                         :is_cygwin => true,
                       })
      opts = {
        :env1_key => :env1_value,
        :env2_key => :env2_value,
      }

      allow(host).to receive(:skip_set_env?).and_return(nil)
      expect(subject).to receive(:construct_env).and_return(opts)

      expect(host).to receive(:ssh_permit_user_environment)
      expect(host).to receive(:ssh_set_user_environment)

      subject.set_env(host, options.merge(opts))
    end
  end
end
