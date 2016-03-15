#
# Copyright 2015-2016, Noah Kantrowitz
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

  context 'on Ubuntu' do
    recipe do
      poise_languages_static '/opt/myapp' do
        source 'http://example.com/myapp.tar'
      end
    end

    it { is_expected.to install_package('tar') }
    it { is_expected.to create_directory('/opt/myapp') }
    it { is_expected.to create_remote_file("#{Chef::Config[:file_cache_path]}/myapp.tar").with(source: 'http://example.com/myapp.tar') }
  end # /context on Ubuntu

  context 'on Solaris' do
    let(:chefspec_options) { {platform: 'solaris2', version: '5.11'} }
    recipe do
      poise_languages_static '/opt/myapp' do
        source 'http://example.com/myapp.tar'
      end
    end

    it { is_expected.to_not install_package('tar') }
    it { is_expected.to create_directory('/opt/myapp') }
    it { is_expected.to create_remote_file("#{Chef::Config[:file_cache_path]}/myapp.tar").with(source: 'http://example.com/myapp.tar') }
  end # /context on Solaris

  context 'on AIX' do
    let(:chefspec_options) { {platform: 'aix', version: '7.1'} }
    recipe do
      poise_languages_static '/opt/myapp' do
        source 'http://example.com/myapp.tar'
      end
    end

    it { is_expected.to_not install_package('tar') }
    it { is_expected.to create_directory('/opt/myapp') }
    it { is_expected.to create_remote_file("#{Chef::Config[:file_cache_path]}/myapp.tar").with(source: 'http://example.com/myapp.tar') }
  end # /context on AIX

  context 'with a .tar URL' do
    recipe do
      poise_languages_static '/opt/myapp' do
        source 'http://example.com/myapp.tar'
      end
    end

    it { is_expected.to install_package('tar') }
    it { expect(unpack_resource.command).to eq %W{tar --strip-components=1 -xvf #{Chef::Config[:file_cache_path]}/myapp.tar} }
  end # /context with a .tar URL

  context 'with a .tar.gz URL' do
    recipe do
      poise_languages_static '/opt/myapp' do
        source 'http://example.com/myapp.tar.gz'
      end
    end

    it { is_expected.to install_package('tar') }
    it { expect(unpack_resource.command).to eq %W{tar --strip-components=1 -xzvf #{Chef::Config[:file_cache_path]}/myapp.tar.gz} }
  end # /context with a .tar.gz URL

  context 'with a .tgz URL' do
    recipe do
      poise_languages_static '/opt/myapp' do
        source 'http://example.com/myapp.tgz'
      end
    end

    it { is_expected.to install_package('tar') }
    it { expect(unpack_resource.command).to eq %W{tar --strip-components=1 -xzvf #{Chef::Config[:file_cache_path]}/myapp.tgz} }
  end # /context with a .tgz URL

  context 'with a .tar.bz2 URL' do
    recipe do
      poise_languages_static '/opt/myapp' do
        source 'http://example.com/myapp.tar.bz2'
      end
    end

    it { is_expected.to install_package(%w{tar bzip2}) }
    it { expect(unpack_resource.command).to eq %W{tar --strip-components=1 -xjvf #{Chef::Config[:file_cache_path]}/myapp.tar.bz2} }
  end # /context with a .tar.bz2 URL

  context 'with a .tbz URL' do
    recipe do
      poise_languages_static '/opt/myapp' do
        source 'http://example.com/myapp.tbz'
      end
    end

    it { is_expected.to install_package(%w{tar bzip2}) }
    it { expect(unpack_resource.command).to eq %W{tar --strip-components=1 -xjvf #{Chef::Config[:file_cache_path]}/myapp.tbz} }
  end # /context with a .tbz URL

  context 'with a .tar.xz URL' do
    recipe do
      poise_languages_static '/opt/myapp' do
        source 'http://example.com/myapp.tar.xz'
      end
    end

    it { is_expected.to install_package(%w{tar xz-utils}) }
    it { expect(unpack_resource.command).to eq %W{tar --strip-components=1 -xJvf #{Chef::Config[:file_cache_path]}/myapp.tar.xz} }
  end # /context with a .tar.xz URL

  context 'with a .txz URL' do
    recipe do
      poise_languages_static '/opt/myapp' do
        source 'http://example.com/myapp.txz'
      end
    end

    it { is_expected.to install_package(%w{tar xz-utils}) }
    it { expect(unpack_resource.command).to eq %W{tar --strip-components=1 -xJvf #{Chef::Config[:file_cache_path]}/myapp.txz} }
  end # /context with a .txz URL

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
