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
require 'chef/version'
require 'shellwords'

describe PoiseLanguages::System::Resource do
  step_into(:poise_languages_system)
  before do
    # Don't actually run any installs. The package hack prevents the usual
    # ChefSpec stubbing from working. This fakes it.
    [Chef::Provider::Package::Apt, Chef::Provider::Package::Yum].each do |klass|
      allow_any_instance_of(klass).to receive(:install_package) {|this| this.new_resource.perform_action(:install, converge_time: true) }
      allow_any_instance_of(klass).to receive(:upgrade_package) {|this| this.new_resource.perform_action(:upgrade, converge_time: true) }
      allow_any_instance_of(klass).to receive(:remove_package) {|this| this.new_resource.perform_action(:remove, converge_time: true) }
      allow_any_instance_of(klass).to receive(:purge_package) {|this| this.new_resource.perform_action(:purge, converge_time: true) }
    end
  end

  context 'on Ubuntu' do
    let(:chefspec_options) { {platform: 'ubuntu', version: '16.04'} }
    before do
      # Stubs load load_current_resource for apt_package.
      allow_any_instance_of(Chef::Provider::Package::Apt).to receive(:shell_out) do |this, *args|
        args.pop if args.last.is_a?(Hash)
        args = Shellwords.split(args.first) if args.size == 1 && args.first.is_a?(String)
        if args[0..1] == %w{apt-cache policy}
          double(stdout: <<-EOH, error!: nil)
#{args[2]}:
  Installed: (none)
  Candidate: 1.2.3-1
  Version table:
     1.2.3-1 500
        500 http://archive.ubuntu.com/ubuntu xenial/main amd64 Packages
EOH
        else
          raise "unstubbed command #{args.inspect}"
        end
      end
    end

    context 'action :install' do
      recipe do
        r = ruby_block 'parent'
        poise_languages_system 'mylang' do
          parent r
          version ''
        end
      end

      if Gem::Requirement.create('>= 12.11').satisfied_by?(Gem::Version.create(Chef::VERSION))
        it { is_expected.to install_package('mylang, mylang-dev') }
      else
        it { is_expected.to install_package('mylang') }
        it { is_expected.to install_package('mylang-dev') }
      end
    end # /context action :upgrade

    context 'action :upgrade' do
      recipe do
        r = ruby_block 'parent'
        poise_languages_system 'mylang' do
          action :upgrade
          parent r
          version ''
        end
      end

      if Gem::Requirement.create('>= 12.11').satisfied_by?(Gem::Version.create(Chef::VERSION))
        it { is_expected.to upgrade_package('mylang, mylang-dev') }
      else
        it { is_expected.to upgrade_package('mylang') }
        it { is_expected.to upgrade_package('mylang-dev') }
      end
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

      if Gem::Requirement.create('>= 12.11').satisfied_by?(Gem::Version.create(Chef::VERSION))
        it { is_expected.to purge_package('mylang, mylang-dev') }
      else
        it { is_expected.to purge_package('mylang') }
        it { is_expected.to purge_package('mylang-dev') }
      end
    end # /context action :uninstall

    context 'with a matching version' do
      recipe do
        r = ruby_block 'parent'
        poise_languages_system 'mylang' do
          parent r
          version '1'
        end
      end

      it { expect { subject }.to_not raise_error }
    end # /context with a matching version

    context 'with an exact matching version' do
      recipe do
        r = ruby_block 'parent'
        poise_languages_system 'mylang' do
          parent r
          version '1.2.3'
        end
      end

      it { expect { subject }.to_not raise_error }
    end # /context with an exact matching version

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

    context 'with a nearby non-matching version' do
      recipe do
        r = ruby_block 'parent'
        poise_languages_system 'mylang' do
          parent r
          version '1.2.4'
        end
      end

      it { expect { subject }.to raise_error PoiseLanguages::Error }
    end # /context with a nearby non-matching version
  end # /context on Ubuntu

  context 'on CentOS' do
    let(:chefspec_options) { {platform: 'centos', version: '7.3.1611'} }
    before do
      if defined?(Chef::Provider::Package::Yum::PythonHelper.instance)
        # New-fangled PythonHelper (Chef 14+).
        python_helper = double('PythonHelper')
        allow(Chef::Provider::Package::Yum::PythonHelper).to receive(:instance).and_return(python_helper)
        allow(python_helper).to receive(:package_query).with(:whatinstalled, 'mylang', version: nil, arch: nil).and_return(Chef::Provider::Package::Yum::Version.new('mylang', nil, nil))
        allow(python_helper).to receive(:package_query).with(:whatinstalled, 'mylang-devel', version: nil, arch: nil).and_return(Chef::Provider::Package::Yum::Version.new('mylang-devel', nil, nil))
        allow(python_helper).to receive(:package_query).with(:whatavailable, 'mylang', version: nil, arch: nil, options: nil).and_return(Chef::Provider::Package::Yum::Version.new('mylang', '0:1.2.3.el7', 'i386'))
        allow(python_helper).to receive(:package_query).with(:whatavailable, 'mylang-devel', version: nil, arch: nil, options: nil).and_return(Chef::Provider::Package::Yum::Version.new('mylang-devel', '0:1.2.3.el7', 'i386'))
      else
        # Old-school yum cache.
        yum_cache = double('YumCache')
        allow(yum_cache).to receive(:yum_binary=)
        allow(yum_cache).to receive(:disable_extra_repo_control)
        allow(yum_cache).to receive(:package_available?).and_return(false)
        allow(yum_cache).to receive(:package_available?).with(/^mylang(-devel)?$/).and_return(true)
        allow(yum_cache).to receive(:installed_version).with(/^mylang(-devel)?$/, nil).and_return(nil)
        allow(yum_cache).to receive(:candidate_version).with(/^mylang(-devel)?$/, nil).and_return('1.2.3')
        allow(Chef::Provider::Package::Yum::YumCache).to receive(:instance).and_return(yum_cache)
      end
    end

    context 'action :install' do
      recipe do
        r = ruby_block 'parent'
        poise_languages_system 'mylang' do
          parent r
          version ''
        end
      end

      if Gem::Requirement.create('>= 12.19').satisfied_by?(Gem::Version.create(Chef::VERSION))
        it { is_expected.to install_package('mylang, mylang-devel') }
      else
        it { is_expected.to install_package('mylang') }
        it { is_expected.to install_package('mylang-devel') }
      end
    end # /context action :upgrade

    context 'action :upgrade' do
      recipe do
        r = ruby_block 'parent'
        poise_languages_system 'mylang' do
          action :upgrade
          parent r
          version ''
        end
      end

      if Gem::Requirement.create('>= 12.19').satisfied_by?(Gem::Version.create(Chef::VERSION))
        it { is_expected.to upgrade_package('mylang, mylang-devel') }
      else
        it { is_expected.to upgrade_package('mylang') }
        it { is_expected.to upgrade_package('mylang-devel') }
      end
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

      if Gem::Requirement.create('>= 12.19').satisfied_by?(Gem::Version.create(Chef::VERSION))
        it { is_expected.to remove_package('mylang, mylang-devel') }
      else
        it { is_expected.to remove_package('mylang') }
        it { is_expected.to remove_package('mylang-devel') }
      end
    end # /context action :uninstall

    context 'with a matching version' do
      recipe do
        r = ruby_block 'parent'
        poise_languages_system 'mylang' do
          parent r
          version '1'
        end
      end

      it { expect { subject }.to_not raise_error }
    end # /context with a matching version

    context 'with an exact matching version' do
      recipe do
        r = ruby_block 'parent'
        poise_languages_system 'mylang' do
          parent r
          version '1.2.3'
        end
      end

      it { expect { subject }.to_not raise_error }
    end # /context with an exact matching version

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

    context 'with a nearby non-matching version' do
      recipe do
        r = ruby_block 'parent'
        poise_languages_system 'mylang' do
          parent r
          version '1.2.4'
        end
      end

      it { expect { subject }.to raise_error PoiseLanguages::Error }
    end # /context with a nearby non-matching version
  end # /context on CentOS
end
