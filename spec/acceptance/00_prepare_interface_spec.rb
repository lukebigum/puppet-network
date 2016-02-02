require 'spec_helper_acceptance'

describe 'network' do
  describe 'prepare a single network interface file' do
    it 'should work with no errors' do
      pp = <<-EOS
network_config { 'eth99':
  ensure      => present,
  onboot      => 'yes',
  ipaddress   => '192.168.0.1',
  netmask     => '255.255.255.0',
  method      => 'none',
  reconfigure => false,
  options     => {
    type   => 'Ethernet',
  }
}
      EOS
      # run twice, test for idempotency
      apply_manifest(pp, :catch_failures => true)
      expect(apply_manifest(pp, :catch_failures => true).exit_code).to be_zero
    end
    describe file('/etc/sysconfig/network-scripts/ifcfg-eth99') do
      it { should be_file }
      its(:content) { should match(/^DEVICE=eth99$/) }
      its(:content) { should match(/^TYPE=Ethernet$/) }
      its(:content) { should match(/^ONBOOT=yes$/) }
      its(:content) { should match(/^IPADDR=192\.168\.0\.1$/) }
      its(:content) { should match(/^NETMASK=255\.255\.255\.0$/) }
    end
  end
end
