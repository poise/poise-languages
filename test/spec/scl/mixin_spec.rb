#
# Copyright 2015-2017, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

describe PoiseLanguages::Scl::Mixin do
  resource(:poise_test)
  provider(:poise_test) do
    include described_class
  end

  describe '#install_scl_package' do
    provider(:poise_test) do
      include Poise
      include described_class
      def scl_package
        {name: 'python34', platform_version: ::Gem::Requirement.create('> 0')}
      end
      def options
        {dev_package: true}
      end
      def action_run
        install_scl_package
      end
    end
    recipe do
      poise_test 'test'
    end

    it { is_expected.to install_poise_languages_scl('python34').with(parent: chef_run.poise_test('test')) }
  end # /describe #install_scl_package

  describe '#uninstall_scl_package' do
    provider(:poise_test) do
      include Poise
      include described_class
      def scl_package
        {name: 'python34', platform_version: ::Gem::Requirement.create('> 0')}
      end
      def options
        {dev_package: true}
      end
      def action_run
        uninstall_scl_package
      end
    end
    recipe do
      poise_test 'test'
    end

    it { is_expected.to uninstall_poise_languages_scl('python34').with(parent: chef_run.poise_test('test')) }
  end # /describe #uninstall_scl_package

  describe '#scl_package' do
    let(:package) { nil }
    recipe(subject: false) do
      poise_test 'test'
    end
    subject { chef_run.poise_test('test').provider_for_action(:run).send(:scl_package) }
    before do
      allow_any_instance_of(provider(:poise_test)).to receive(:options).and_return({})
      allow(provider(:poise_test)).to receive(:find_scl_package).and_return(package)
    end

    context 'with a valid package' do
      let(:package) { {name: 'python34'} }
      it { is_expected.to eq(package) }
    end # /context with a valid package

    context 'without a valid package' do
      it { expect { subject }.to raise_error PoiseLanguages::Error }
    end # /context without a valid package
  end # /describe #scl_package

  describe '#scl_folder' do
    let(:test_provider) { provider(:poise_test).new(resource(:poise_test).new('test'), nil) }
    subject { test_provider.send(:scl_folder) }
    before do
      allow(test_provider).to receive(:scl_package).and_return({name: 'python34'})
    end

    it { is_expected.to eq '/opt/rh/python34' }
  end # /describe #scl_folder

  describe '#scl_environment' do
    let(:test_provider) { provider(:poise_test).new(resource(:poise_test).new('test'), nil) }
    subject { test_provider.send(:scl_environment) }
    before do
      allow(test_provider).to receive(:scl_package).and_return({name: 'python34'})
    end

    it do
      expect(test_provider).to receive(:parse_enable_file).with('/opt/rh/python34/enable')
      subject
    end
  end # /describe #scl_environment

  describe '#parse_enable_file' do
    let(:content) { '' }
    before do
      allow(File).to receive(:exist?).with('/test/enable').and_return(true)
      allow(IO).to receive(:readlines).with('/test/enable').and_return(content.split(/\n/))
    end
    subject { provider(:poise_test).new(resource(:poise_test).new('test'), nil).send(:parse_enable_file, '/test/enable') }

    context 'with an empty file' do
      it { is_expected.to eq({}) }
    end # /context with an empty file

    context 'with valid data' do
      # $ cat /opt/rh/python33/enable
      let(:content) { <<-EOH }
export PATH=/opt/rh/python33/root/usr/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/opt/rh/python33/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
export MANPATH=/opt/rh/python33/root/usr/share/man:${MANPATH}
# For systemtap
export XDG_DATA_DIRS=/opt/rh/python33/root/usr/share${XDG_DATA_DIRS:+:${XDG_DATA_DIRS}}
# For pkg-config
export PKG_CONFIG_PATH=/opt/rh/python33/root/usr/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}
EOH
      it do
        is_expected.to eq({
          'PATH' => "/opt/rh/python33/root/usr/bin#{ENV['PATH'] ? ':' + ENV['PATH'] : ''}",
          'LD_LIBRARY_PATH' => "/opt/rh/python33/root/usr/lib64#{ENV['LD_LIBRARY_PATH'] ? ':' + ENV['LD_LIBRARY_PATH'] : ''}",
          'MANPATH' => "/opt/rh/python33/root/usr/share/man:#{ENV['MANPATH']}",
          'XDG_DATA_DIRS' => "/opt/rh/python33/root/usr/share#{ENV['XDG_DATA_DIRS'] ? ':' + ENV['XDG_DATA_DIRS'] : ''}",
          'PKG_CONFIG_PATH' => "/opt/rh/python33/root/usr/lib64/pkgconfig#{ENV['PKG_CONFIG_PATH'] ? ':' + ENV['PKG_CONFIG_PATH'] : ''}",
          })
      end
    end # /context with valid data

    context 'with a non-existent file' do
      before do
        allow(File).to receive(:exist?).with('/test/enable').and_return(false)
      end
      it { is_expected.to eq({}) }
    end # /context with a non-existent file

    context 'with an scl_source line' do
      # $ cat /opt/rh/nodejs010/enable
      let(:content) { <<-EOH }
export PATH=/opt/rh/nodejs010/root/usr/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/opt/rh/nodejs010/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
export PYTHONPATH=/opt/rh/nodejs010/root/usr/lib/python2.7/site-packages${PYTHONPATH:+:${PYTHONPATH}}
export MANPATH=/opt/rh/nodejs010/root/usr/share/man:$MANPATH
. scl_source enable v8314
EOH
      let(:v8_content) { <<-EOH }
export PATH=/opt/rh/v8314/root/usr/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/opt/rh/v8314/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
export PYTHONPATH=/opt/rh/v8314/root/usr/lib/python2.7/site-packages${PYTHONPATH:+:${PYTHONPATH}}
export MANPATH=/opt/rh/v8314/root/usr/share/man:$MANPATH
export PKG_CONFIG_PATH=/opt/rh/v8314/root/usr/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}
export CPATH=/opt/rh/v8314/root/usr/include${CPATH:+:${CPATH}}
export LIBRARY_PATH=/opt/rh/v8314/root/usr/lib64${LIBRARY_PATH:+:${LIBRARY_PATH}}
EOH

      before do
        allow(File).to receive(:exist?).with('/opt/rh/v8314/enable').and_return(true)
        allow(IO).to receive(:readlines).with('/opt/rh/v8314/enable').and_return(v8_content.split(/\n/))
      end

      it do
        is_expected.to eq({
          'PATH' => "/opt/rh/v8314/root/usr/bin:/opt/rh/nodejs010/root/usr/bin#{ENV['PATH'] ? ':' + ENV['PATH'] : ''}",
          'LD_LIBRARY_PATH' => "/opt/rh/v8314/root/usr/lib64:/opt/rh/nodejs010/root/usr/lib64#{ENV['LD_LIBRARY_PATH'] ? ':' + ENV['LD_LIBRARY_PATH'] : ''}",
          'PYTHONPATH' => "/opt/rh/v8314/root/usr/lib/python2.7/site-packages:/opt/rh/nodejs010/root/usr/lib/python2.7/site-packages#{ENV['PYTHONPATH'] ? ':' + ENV['PYTHONPATH'] : ''}",
          'MANPATH' => "/opt/rh/v8314/root/usr/share/man:/opt/rh/nodejs010/root/usr/share/man:#{ENV['MANPATH']}",
          'PKG_CONFIG_PATH' => "/opt/rh/v8314/root/usr/lib64/pkgconfig#{ENV['PKG_CONFIG_PATH'] ? ':' + ENV['PKG_CONFIG_PATH'] : ''}",
          'CPATH' => "/opt/rh/v8314/root/usr/include#{ENV['CPATH'] ? ':' + ENV['CPATH'] : ''}",
          'LIBRARY_PATH' => "/opt/rh/v8314/root/usr/lib64#{ENV['LIBRARY_PATH'] ? ':' + ENV['LIBRARY_PATH'] : ''}",
          })
      end
    end # /context with an scl_source line
  end # /describe #parse_enable_file

  describe '.default_inversion_options' do
    provider(:poise_test) do
      include Poise(inversion: :poise_test)
      include described_class
    end
    let(:node) { double('node') }
    let(:new_resource) { double('resource') }
    subject { provider(:poise_test).default_inversion_options(node, new_resource) }
    it { is_expected.to eq({dev_package: true, package_name: nil, package_version: nil, package_upgrade: false}) }
  end # /describe .default_inversion_options

  describe '.provides_auto?' do
    let(:node) { double('node', :"[]" => {'machine' => 'x86_64'}) }
    let(:new_resource) { double('resource') }
    subject { provider(:poise_test).provides_auto?(node, new_resource) }
    before do
      allow(node).to receive(:platform?) {|*names| names.include?('redhat') || names.include?('centos') }
      allow(provider(:poise_test)).to receive(:inversion_options).with(node, new_resource).and_return({})
      allow(provider(:poise_test)).to receive(:find_scl_package).with(node, nil).and_return({})
    end
    it { is_expected.to be true }
  end # /describe .provides_auto?

  describe '.find_scl_package' do
    let(:version) { '' }
    provider(:poise_test) do
      include described_class
      scl_package('3.4.2', 'rh-python34', 'rh-python34-python-devel', '>= 7.0')
      scl_package('3.3.2', 'python33', 'python33-python-devel')
    end
    subject { provider(:poise_test).send(:find_scl_package, chef_run.node, version) }

    context 'on CentOS 7 with no version' do
      let(:chefspec_options) { {platform: 'centos', version: '7.3.1611'} }
      it do
        is_expected.to include({
          version: '3.4.2',
          name: 'rh-python34',
          devel_name: 'rh-python34-python-devel',
        })
      end
    end # /context on CentOS 7 with no version

    context 'on CentOS 7 with a version' do
      let(:version) { '3.3' }
      let(:chefspec_options) { {platform: 'centos', version: '7.3.1611'} }
      it do
        is_expected.to include({
          version: '3.3.2',
          name: 'python33',
          devel_name: 'python33-python-devel',
        })
      end
    end # /context on CentOS 7 with a version

    context 'on CentOS 6 with no version' do
      let(:chefspec_options) { {platform: 'centos', version: '6.8'} }
      it do
        is_expected.to include({
          version: '3.3.2',
          name: 'python33',
          devel_name: 'python33-python-devel',
        })
      end
    end # /context on CentOS 6 with no version

    context 'on CentOS 6 with a version' do
      let(:version) { '3.3' }
      let(:chefspec_options) { {platform: 'centos', version: '6.8'} }
      it do
        is_expected.to include({
          version: '3.3.2',
          name: 'python33',
          devel_name: 'python33-python-devel',
        })
      end
    end # /context on CentOS 6 with a version

    context 'with no devel package' do
      provider(:poise_test) do
        include described_class
        scl_package('3.4.2', 'rh-python34')
      end
      let(:chefspec_options) { {platform: 'centos', version: '7.3.1611'} }
      it do
        is_expected.to include({
          version: '3.4.2',
          name: 'rh-python34',
          devel_name: nil,
        })
      end
    end # /context with no devel package
  end # /describe .find_scl_package
end
