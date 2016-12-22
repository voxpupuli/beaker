require 'beaker/hypervisor/vagrant'

class Beaker::VagrantVirtualbox < Beaker::Vagrant
  def provision(provider = 'virtualbox')
    super
  end

  # Generate a VM customization string
  def self.vb_customize(command, args)
    "      vb.customize ['#{command}', #{args.map{|a| "'#{a.to_s}'"}.join(", ")}]\n"
  end

  # Generate a VM customization string for the current VM
  def self.vb_customize_vm(command, args)
    "      vb.customize ['#{command}', :id, #{args.map{|a| "'#{a.to_s}'"}.join(", ")}]\n"
  end

  def self.provider_vfile_section(host, options)
    # Allow memory and CPUs to be set at a per node level or overall, and take the most specific setting
    provider_section  = ""
    provider_section << "    v.vm.provider :virtualbox do |vb|\n"
    provider_section << "      vb.customize ['modifyvm', :id, '--memory', '#{memsize(host,options)}', '--cpus', '#{cpus(host,options)}']\n"
    provider_section << "      vb.vbguest.auto_update = false" if options[:vbguest_plugin] == 'disable'

    # Guest volume support
    # - Creates a new AHCI controller with the requisite number of ports,
    #   the default controller is limited in its number of supported ports (2).
    #   The AHCI emulation is generic enough for acceptance testing, and
    #   presents the devices as SCSI devices in /sys/class/scsi_disk.
    # - Creates the defined volumes in beaker's temporary folder and attaches
    #   them to the controller in order starting at port 0.  This presents disks
    #   as 2:0:0:0, 3:0:0:0 ... much like you'd see on commercial storage boxes
    if host['volumes']
      provider_section << self.vb_customize_vm('storagectl', [
        '--name', 'SATA Controller',
        '--add', 'sata',
        '--controller', 'IntelAHCI',
        '--portcount', host['volumes'].length
      ])
      host['volumes'].keys.each_with_index do |volume, index|
        volume_path = "#{host.name}-#{volume}.vdi"
        provider_section << self.vb_customize('createhd', [
          '--filename', volume_path,
          '--size', host['volumes'][volume]['size'],
        ])
        provider_section << self.vb_customize_vm('storageattach', [
          '--storagectl', 'SATA Controller',
          '--port', index,
          '--device', 0,
          '--type', 'hdd',
          '--medium', volume_path,
        ])
      end
    end

    provider_section << "      vb.customize [\"modifyvm\", :id, \"--natdnshostresolver1\", \"#{host['natdns']}\"]\n" unless host['natdns'].nil?

    provider_section << "      vb.customize [\"modifyvm\", :id, \"--natdnsproxy1\", \"#{host['natdns']}\"]\n" unless host['natdns'].nil?

    provider_section << "      vb.gui = true\n" unless host['vb_gui'].nil?

    provider_section << "      [\"modifyvm\", :id, \"--cpuidset\", \"1\",\"000206a7\",\"02100800\",\"1fbae3bf\",\"bfebfbff\"\]" if /osx/i.match(host['platform'])

    if host['disk_path']
      unless File.exist?(host['disk_path'])
        host['disk_path'] = File.join(host['disk_path'], "#{host.name}.vmdk")
        provider_section << "      vb.customize ['createhd', '--filename', '#{host['disk_path']}', '--size', #{host['disk_size'] ||= 5 * 1024}, '--format', 'vmdk']\n"
      end
      provider_section << "      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium','#{host['disk_path']}']\n"
    end

    provider_section << "    end\n"

    provider_section
  end
end
