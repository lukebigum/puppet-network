require 'ipaddr'
require 'puppetx/filemapper'

Puppet::Type.type(:network_route).provide(:redhat) do
  # RHEL network_route routes provider.
  #
  # This provider uses the filemapper mixin to map the routes file to a
  # collection of network_route providers, and back.
  #
  # @see https://access.redhat.com/knowledge/docs/en-US/Red_Hat_Enterprise_Linux/6/html/Deployment_Guide/s1-networkscripts-static-routes.html

  include PuppetX::FileMapper

  desc 'RHEL style routes provider'

  confine :osfamily => :redhat
  defaultfor :osfamily => :redhat

  has_feature :provider_options

  def select_file
    "/etc/sysconfig/network-scripts/route-#{@resource[:interface]}"
  end

  def self.target_files
    Dir['/etc/sysconfig/network-scripts/route-*']
  end

  def self.parse_file(filename, contents)
    routes = []

    lines = contents.split("\n")
    lines.each do |line|
      # Strip off any trailing comments
      line.sub!(/#.*$/, '')

      if line =~ /^\s*#|^\s*$/
        # Ignore comments and blank lines
        next
      end

      route = line.split(' ', 6)
      if route.length < 3
        fail Puppet::Error, 'Malformed redhat route file, cannot instantiate network_route resources'
      end

      new_route = {}

      if route[0] == 'default'
        cidr_target = 'default'

        new_route[:name]    = cidr_target
        new_route[:network] = 'default'
        new_route[:netmask] = '0.0.0.0'
        new_route[:gateway] = route[2]
        new_route[:options] = route[5] if route[5]
      else
        # use the CIDR version of the target as :name
        network, netmask = route[0].split('/')
        # LB: the address may be in /CIDR format or /netmask format, handle both
        if netmask =~ /\./
          cidr_target = "#{network}/#{IPAddr.new(netmask).to_i.to_s(2).count('1')}"
        else
          cidr_target = "#{network}/#{netmask}"
          netmask = IPAddr.new('255.255.255.255').mask(netmask).to_s
        end

        new_route[:name]    = cidr_target
        new_route[:network] = network
        new_route[:netmask] = netmask
        new_route[:gateway] = route[2]
        new_route[:options] = route[5] if route[5]
      end

      # LB: the interface to apply to can be read from multiple places, either on the route
      # line itself or from the filename under /etc/sysconfig/network-scripts/route-<IFACE>
      if route[4]
        new_route[:interface] = route[4]
      else
        new_route[:interface] = File.basename(filename).split('-')[1]
      end

      routes << new_route
    end

    routes
  end

  # Generate an array of sections
  def self.format_file(_filename, providers)
    contents = []
    contents << header
    # Build routes
    providers.sort_by(&:name).each do |provider|
      [:network, :netmask, :gateway, :interface].each do |prop|
        fail Puppet::Error, "#{provider.name} does not have a #{prop}." if provider.send(prop).nil?
      end
      #LB: don't write 'absent' provider options to disk
      options = " #{provider.options}" unless provider.options == :absent
      contents << if provider.network == 'default'
                    "#{provider.network} via #{provider.gateway} dev #{provider.interface}#{options}\n"
                  else
                    "#{provider.network}/#{provider.netmask} via #{provider.gateway} dev #{provider.interface}#{options}\n"
                  end
    end
    contents.join
  end

  def self.header
    str = <<-HEADER
# HEADER: This file is is being managed by puppet. Changes to
# HEADER: routes that are not being managed by puppet will persist;
# HEADER: however changes to routes that are being managed by puppet will
# HEADER: be overwritten. In addition, file order is NOT guaranteed.
# HEADER: Last generated at: #{Time.now}
HEADER
    str
  end
end
