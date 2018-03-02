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

describe PoiseLanguages::Scl::Resource do
  step_into(:poise_languages_scl)
  step_into(:ruby_block)
  let(:chefspec_options) { {platform: 'centos', version: '7.3.1611'} }
  let(:yum_cache) { double('yum_cache', reload: nil) }
  before do
    allow(Chef::Provider::Package::Yum::YumCache).to receive(:instance).and_return(yum_cache)
  end

  context 'action :install' do
    recipe do
      r = ruby_block 'parent' do
        block { }
      end
      poise_languages_scl 'mylang' do
        dev_package 'mylang-devel'
        parent r
      end
    end

    it { is_expected.to upgrade_package('centos-release-scl-rh') }
    it { is_expected.to install_package('mylang') }
    it { is_expected.to install_package('mylang-devel') }
    it { expect(yum_cache).to receive(:reload); run_chef }
  end # /context action :install

  context 'action :upgrade' do
    recipe do
      r = ruby_block 'parent' do
        block { }
      end
      poise_languages_scl 'mylang' do
        action :upgrade
        dev_package 'mylang-devel'
        parent r
      end
    end

    it { is_expected.to upgrade_package('centos-release-scl-rh') }
    it { is_expected.to upgrade_package('mylang') }
    it { is_expected.to upgrade_package('mylang-devel') }
    it { expect(yum_cache).to receive(:reload); run_chef }
  end # /context action :upgrade

  context 'action :uninstall' do
    recipe do
      r = ruby_block 'parent' do
        block { }
      end
      poise_languages_scl 'mylang' do
        action :uninstall
        dev_package 'mylang-devel'
        parent r
      end
    end

    it { is_expected.to remove_package('mylang') }
    it { is_expected.to remove_package('mylang-devel') }
  end # /context action :uninstall
end
