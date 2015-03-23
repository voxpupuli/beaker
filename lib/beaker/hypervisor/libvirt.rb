# TODO: rework qcow handling to do this:
# virsh vol-create-as default guest 2048MB
# virsh vol-upload --pool default guest file.qcow2
# virsh vol-delete --pool default guest
module Beaker
  class Libvirt < Beaker::Hypervisor

    def initialize(hosts, options)
      require 'tempfile'
      @options = options
      @logger = options[:logger]
      @hosts = hosts
      @logger.notify "Connecting to libvirt"

    end

    def provision
      @logger.notify "Provisioning libvirt"
      #conn = ::Libvirt::open('qemu:///system')

      @hosts.each do |host|
        file = Tempfile.new(host.name)
        img = Tempfile.new(host.name + "2")
        temporary_name = file.path.split('/')[-1]
        host['tempname'] = temporary_name
        host['qcowfile'] = img.path
        @logger.notify "provisioning #{host.name} as #{host['tempname']}"
        FileUtils.cp host['qcow2'], img.path

        new_dom_xml = <<EOF
<domain type='kvm'>
  <name>#{host['tempname']}</name>
  <memory unit='MiB'>2048</memory>
  <vcpu>1</vcpu>
  <os>
    <type arch='x86_64'>hvm</type>
    <boot dev='hd'/>
    <bootmenu enable='no'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='unsafe'/>
      <source file='#{img.path}'/>
      <target dev='sda' bus='sata'/>
      <address type='drive' controller='0' bus='0' unit='0'/>
    </disk>
    <controller type='ide' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x1'/>
    </controller>
    <input type='mouse' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes'/>
    <video>
      <model type='cirrus' vram='9216' heads='1'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>
    <memballoon model='virtio'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
    </memballoon>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
  </devices>
</domain>
EOF
        @logger.notify "Creating transient domain ruby-libvirt-tester"
        file.write(new_dom_xml)
        file.close
        `virsh define #{file.path}`
        `virsh start #{host['tempname']}`
        sleep(30)
        file.delete
        xml = `virsh dumpxml #{host['tempname']}`
        xml =~ /([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2})/
        mac = $1
        arp = `arp `
        ip = ""
        arp.each_line do |line|
          if line =~ /#{mac}/
            ip = line.split()[0]
          end
        end
        forward_ssh_agent = @options[:forward_ssh_agent] || false
        # Update host metadata
        host['ip']  = ip
        host['port'] = 22
        host['user'] = host['user']
        host['password'] = host['password']
        host['ssh']  = {
          :port => 22,
          :forward_agent => forward_ssh_agent,
          :keys => host['private_key_file'],

        }
        #dom = conn.create_domain_xml(new_dom_xml)
        #enable root if user is not root
        enable_root_on_hosts()
      end

    end

    def cleanup
      @logger.notify "Cleaning up libvirt"
      @logger.notify "Destroying transient domain ruby-libvirt-tester"
      #dom.destroy
      #conn.close
      @hosts.each do |host|
        `virsh destroy #{host['tempname']}`
        `virsh undefine #{host['tempname']}`
        FileUtils.rm host['qcowfile'], :force => true

      end
    end

    def enable_root_on_hosts
      @hosts.each do |host|
        enable_root(host)
      end
    end

    # Enables root access for a host when username is not root
    #
    # @return [void]
    # @api private
    def enable_root(host)
      if host['user'] != 'root'
        copy_ssh_to_root(host, @options)
        enable_root_login(host, @options)
        host['user'] = 'root'
        host.close
      end
    end

  end
end
