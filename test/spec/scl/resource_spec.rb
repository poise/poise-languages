#
# Copyright 2015, Noah Kantrowitz
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
  let(:chefspec_options) { {platform: 'centos', version: '7.0'} }

  context 'action :install' do
    recipe do
      r = ruby_block 'parent'
      poise_languages_scl 'mylang' do
        parent r
        url 'http://mylang.rpm'
      end
    end

    it { is_expected.to upgrade_package('scl-utils') }
    it { is_expected.to install_rpm_package('rhscl-mylang').with(source: 'http://mylang.rpm') }
    it { is_expected.to install_yum_package('mylang').with(flush_cache: {before: true}) }
  end # /context action :install

  context 'action :uninstall' do
    recipe do
      r = ruby_block 'parent'
      poise_languages_scl 'mylang' do
        action :uninstall
        parent r
        url 'http://mylang.rpm'
      end
    end

    it { is_expected.to remove_package('scl-utils') }
    it { is_expected.to remove_rpm_package('rhscl-mylang') }
    it { is_expected.to remove_yum_package('mylang') }
  end # /context action :uninstall
end
