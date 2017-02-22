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

describe PoiseLanguages::System::Resource do
  let(:chefspec_options) { {platform: 'ubuntu', version: '14.04'} }
  step_into(:poise_languages_system)
  step_into(:package, unwrap_notifying_block: false)
  provider(:package_hack, parent: Chef::Provider::Package) do
    def load_current_resource
      @current_resource = new_resource.class.new(new_resource.name, run_context)
      current_resource.package_name(new_resource.package_name)
      candidate = node['poise_candidate']
      current = node['poise_current']
      @candidate_version = if new_resource.package_name.is_a?(Array)
        current_resource.version([current] * new_resource.package_name.length)
        [candidate] * new_resource.package_name.length
      else
        current_resource.version(current)
        candidate
      end
      current_resource
    end
    def install_package(name, version)
      rc = defined?(Chef.run_context) ? Chef.run_context : self.run_context
      rc.resource_collection << new_resource unless rc.resource_collection.keys.include?(new_resource.to_s)
    end
    alias_method :upgrade_package, :install_package
    alias_method :remove_package, :install_package
    alias_method :purge_package, :install_package
  end
  recipe do
    r = ruby_block 'parent'
    poise_languages_system 'mylang' do
      parent r
      version ''
    end
  end
  before do
    # I can't use the provider resolver system easily because overrides like this
    # don't work well with the Halite patcher.
    allow_any_instance_of(Chef::Resource::Package).to receive(:provider).and_return(provider(:package_hack))
    # Set our candidate version.
    default_attributes[:poise_candidate] = '1.0'
  end

  context 'on Ubuntu' do
    it { is_expected.to install_apt_package('mylang, mylang-dev') }
  end # /context on Ubuntu

  context 'on CentOS' do
    let(:chefspec_options) { {platform: 'centos', version: '7.0'} }

    it { is_expected.to install_yum_package('mylang') }
    it { is_expected.to install_yum_package('mylang-devel') }
  end # /context on Ubuntu

  context 'action :upgrade' do
    recipe do
      r = ruby_block 'parent'
      poise_languages_system 'mylang' do
        action :upgrade
        parent r
        version ''
      end
    end

    it { is_expected.to upgrade_apt_package('mylang, mylang-dev') }
  end # /context action :upgrade

  context 'action :uninstall' do
    recipe do
      r = ruby_block 'parent'
      poise_languages_system 'mylang' do
        action :uninstall
        parent r
        version ''
      end
    end
    before do
      default_attributes[:poise_current] = '2.0'
    end

    it { is_expected.to purge_apt_package('mylang, mylang-dev') }
  end # /context action :uninstall

  context 'with a matching version' do
    recipe do
      r = ruby_block 'parent'
      poise_languages_system 'mylang' do
        parent r
        version '1'
      end
    end

    it { is_expected.to install_apt_package('mylang, mylang-dev') }
  end # /context with a matching version

  context 'with a non-matching version' do
    recipe do
      r = ruby_block 'parent'
      poise_languages_system 'mylang' do
        parent r
        version '2'
      end
    end

    it { expect { subject }.to raise_error PoiseLanguages::Error }
  end # /context with a non-matching version
end
