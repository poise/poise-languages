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

describe PoiseLanguages::System::Mixin do
  resource(:poise_test)
  provider(:poise_test) do
    include described_class
  end

  describe '#install_system_packages' do
    let(:chefspec_options) { {platform: 'ubuntu', version: '16.04'} }
    provider(:poise_test) do
      include Poise
      include described_class
      def system_package_name
        'mylang'
      end
      def options
        {}
      end
      def action_run
        install_system_packages
      end
    end
    recipe do
      poise_test 'test'
    end

    it { is_expected.to install_poise_languages_system('mylang').with(parent: chef_run.poise_test('test'),
                                                                      dev_package: 'mylang-dev',
                                                                      dev_package_overrides: {},
                                                                      package_version: nil,
                                                                      version: '') }

    context 'with a block override' do
      provider(:poise_test) do
        include Poise
        include described_class
        def system_package_name
          'mylang'
        end
        def options
          {}
        end
        def action_run
          install_system_packages do
            dev_package false
          end
        end
      end

      it { is_expected.to install_poise_languages_system('mylang').with(parent: chef_run.poise_test('test'),
                                                                        dev_package: false,
                                                                        dev_package_overrides: {},
                                                                        package_version: nil,
                                                                        version: '') }
    end # /context with a block override
  end # /describe #install_system_packages

  describe '#uninstall_system_packages' do
    provider(:poise_test) do
      include Poise
      include described_class
      def system_package_name
        'mylang'
      end
      def options
        {}
      end
      def action_run
        uninstall_system_packages
      end
    end
    recipe do
      poise_test 'test'
    end

    it { is_expected.to uninstall_poise_languages_system('mylang') }

    context 'with a block override' do
      provider(:poise_test) do
        include Poise
        include described_class
        def system_package_name
          'mylang'
        end
        def options
          {}
        end
        def action_run
          uninstall_system_packages do
            dev_package false
          end
        end
      end

      it { is_expected.to uninstall_poise_languages_system('mylang').with(dev_package: false) }
    end # /context with a block override
  end # /describe #uninstall_system_packages

  describe '#system_package_candidates' do
    subject { provider(:poise_test).new(resource(:poise_test).new('test'), nil).send(:system_package_candidates, '') }
    it { expect { subject }.to raise_error NotImplementedError }
  end # /describe #system_package_candidates

  describe '#system_package_name' do
    let(:chefspec_options) { {platform: 'debian', version: '7.11'} }
    let(:version) { '' }
    let(:test_provider) { provider(:poise_test).new(resource(:poise_test).new('test'), chef_run.run_context) }
    provider(:poise_test) do
      include described_class
      packages('python', {
        debian: {
          '~> 8.0' => %w{python3.4 python2.7},
          '~> 7.0' => %w{python3.2 python2.7 python2.6},
          '~> 6.0' => %w{python3.1 python2.6 python2.5},
        },
        ubuntu: {
          '14.04' => %w{python3.4 python2.7},
          '12.04' => %w{python3.2 python2.7},
          '10.04' => %w{python3.1 python2.6},
        },
      })

      def system_package_candidates(version)
        %w{python3.4 python3.3 python3.2 python3.1 python3.0 python2.7 python2.6}.select {|pkg| pkg.start_with?("python#{version}") } + %w{python}
      end
    end
    subject { test_provider.send(:system_package_name) }
    before do
      allow(test_provider).to receive(:options).and_return({'version' => version})
    end

    context 'with a blank version' do
      it { is_expected.to eq 'python3.2' }
    end # /context with a blank version

    context 'with version 3' do
      let(:version) { '3' }
      it { is_expected.to eq 'python3.2' }
    end # /context with version 3

    context 'with version 2' do
      let(:version) { '2' }
      it { is_expected.to eq 'python2.7' }
    end # /context with version 2

    context 'with version 2.6' do
      let(:version) { '2.6' }
      it { is_expected.to eq 'python2.6' }
    end # /context with version 2.6

    context 'on an unknown platform' do
      let(:chefspec_options) { {platform: 'centos', version: '7.3.1611'} }
      it { is_expected.to eq 'python' }
    end # /context on an unknown platform

    context 'with no valid package' do
      provider(:poise_test) do
        include described_class
        packages(nil, {})

        def system_package_candidates(version)
          []
        end
      end
      it { expect { subject }.to raise_error PoiseLanguages::Error }
    end # /context with no valid package
  end # /describe #system_package_name

  describe '#system_dev_package_overrides' do
    subject { provider(:poise_test).new(resource(:poise_test).new('test'), nil).send(:system_dev_package_overrides) }
    it { is_expected.to eq({}) }
  end # /describe #system_dev_package_overrides

  describe '.provides_auto?' do
    provider(:poise_test) do
      include Poise(inversion: :poise_test)
      include described_class
    end
    subject { provider(:poise_test).provides_auto?(chef_run.node, nil) }

    context 'on CentOS' do
      let(:chefspec_options) { {platform: 'centos', version: '7.3.1611'} }
      it { is_expected.to be true }
    end # /context on CentOS

    context 'on Windows' do
      let(:chefspec_options) { {platform: 'windows', version: '2012R2'} }
      it { is_expected.to be false }
    end # /context on Windows

    context 'on an unknown platform' do
      it { is_expected.to be true }
    end # /context on an unknown platform
  end # /describe .provides_auto?

  describe '.default_inversion_options' do
    provider(:poise_test) do
      include Poise(inversion: :poise_test)
      include described_class
    end
    subject { provider(:poise_test).default_inversion_options(nil, nil) }

    it { is_expected.to be_a(Hash) }
  end # /describe .default_inversion_options
end
