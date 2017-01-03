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

describe PoiseLanguages::Static::Resource do
  let(:chefspec_options) { {platform: 'ubuntu', version: '14.04'} }
  step_into(:poise_languages_static)
  let(:unpack_resource) do
    chef_run.execute('unpack archive')
  end

  context 'action :install' do
    recipe do
      poise_languages_static '/opt/myapp' do
        source 'http://example.com/myapp.tar'
      end
    end

    it { is_expected.to create_directory('/opt/myapp').with(user: 0, group: 0, mode: '755') }
    it { is_expected.to create_remote_file("#{Chef::Config[:file_cache_path]}/myapp.tar").with(user: 0, group: 0, mode: '644', source: 'http://example.com/myapp.tar', retries: 5) }
  end # /context 'action :install

  context 'action :uninstall' do
    recipe do
      poise_languages_static '/opt/myapp' do
        action :uninstall
        source 'http://example.com/myapp.tar'
      end
    end

    it { is_expected.to delete_directory('/opt/myapp').with(recursive: true) }
    it { is_expected.to delete_file("#{Chef::Config[:file_cache_path]}/myapp.tar") }
  end # /context action :uninstall
end
