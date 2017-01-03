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

describe PoiseLanguages::Command::Mixin do
  resource(:mylang_runtime) do
    include Poise(container: true)
    attribute(:mylang_binary, default: '/binary')
    attribute(:mylang_environment, default: {'MYLANG_PATH' => '/thing'})
  end
  provider(:mylang_runtime)
  let(:runtime) { chef_run.mylang_runtime('parent') }
  before do
    allow(PoiseLanguages::Utils).to receive(:which) do |name|
      "/which/#{name}"
    end
  end

  describe PoiseLanguages::Command::Mixin::Resource do
    resource(:poise_test) do
      klass = described_class
      include Module.new {
        include klass
        language_command_mixin(:mylang)
      }
    end
    provider(:poise_test)

    describe '#parent_$name' do
      context 'with a parent' do
        recipe do
          mylang_runtime 'parent'
          poise_test 'test'
        end
        it { is_expected.to run_poise_test('test').with(parent_mylang: chef_run.mylang_runtime('parent')) }
      end # /context with a parent

      context 'with no parent' do
        recipe do
          poise_test 'test'
        end
        it { is_expected.to run_poise_test('test').with(parent_mylang: nil) }
      end # /context with no parent

      context 'with two containers' do
        recipe do
          mylang_runtime 'parent'
          poise_test 'test'
          mylang_runtime 'other'
        end

        it { is_expected.to run_poise_test('test').with(parent_mylang: chef_run.mylang_runtime('parent')) }
      end # /context with two containers
    end # /describe #parent_$name

    describe '#timeout' do
      recipe do
        poise_test 'test' do
          # Be explicit because Kernel#timeout is part of the timeout.rb lib.
          self.timeout(123)
        end
      end

      context 'with timeout enabled' do
        it { is_expected.to run_poise_test('test').with(timeout: 123) }
      end # /context with timeout enabled

      context 'with timeout disabled' do
        resource(:poise_test) do
          klass = described_class
          include Module.new {
            include klass
            language_command_mixin(:poise, timeout: false)
          }
        end
        it { expect { subject }.to raise_error NoMethodError }
      end # /context with timeout disabled
    end # /describe #timeout

    describe '#$name' do
      context 'with an implicit parent' do
        recipe do
          mylang_runtime 'parent'
          poise_test 'test'
        end

        it { is_expected.to run_poise_test('test').with(parent_mylang: runtime, mylang: '/binary') }
      end # /context with an implicit parent

      context 'with a parent resource' do
        recipe do
          r = mylang_runtime 'parent'
          poise_test 'test' do
            mylang r
          end
        end

        it { is_expected.to run_poise_test('test').with(parent_mylang: runtime, mylang: '/binary') }
      end # /context with a parent resource

      context 'with a parent resource name' do
        recipe do
          mylang_runtime 'parent'
          poise_test 'test' do
            mylang 'parent'
          end
        end

        it { is_expected.to run_poise_test('test').with(parent_mylang: runtime, mylang: '/binary') }
      end # /context with a parent resource name

      context 'with a parent resource name that looks like a path' do
        let(:runtime) { chef_run.mylang_runtime('/usr/bin/other') }
        recipe do
          mylang_runtime '/usr/bin/other' do
            mylang_binary name
          end
          poise_test 'test' do
            mylang '/usr/bin/other'
          end
        end

        it { is_expected.to run_poise_test('test').with(parent_mylang: runtime, mylang: '/usr/bin/other') }
      end # /context with a parent resource name that looks like a path

      context 'with a path' do
        recipe do
          poise_test 'test' do
            mylang '/usr/bin/other'
          end
        end

        it { is_expected.to run_poise_test('test').with(parent_mylang: nil, mylang: '/usr/bin/other') }
      end # /context with a path

      context 'with a path and an implicit parent' do
        recipe do
          mylang_runtime 'parent'
          poise_test 'test' do
            mylang '/usr/bin/other'
          end
        end

        it { is_expected.to run_poise_test('test').with(parent_mylang: runtime, mylang: '/usr/bin/other') }
      end # /context with a path and an implicit parent

      context 'with an invalid parent' do
        recipe do
          poise_test 'test' do
            mylang 'test'
          end
        end

        it { expect { subject }.to raise_error Chef::Exceptions::ResourceNotFound }
      end # /context with an invalid parent

      context 'with no parent' do
        recipe do
          poise_test 'test'
        end

        it { is_expected.to run_poise_test('test').with(parent_mylang: nil, mylang: '/which/mylang') }
      end # /context with no parent
    end # /describe #$name

    describe '#$name_from_parent' do
      context 'with a resource parent' do
        recipe do
          mylang_runtime 'parent'
          r = poise_test 'first' do
            mylang 'parent'
          end
          mylang_runtime 'other'
          poise_test 'test' do
            mylang_from_parent r
          end
        end

        it { is_expected.to run_poise_test('test').with(parent_mylang: runtime, mylang: '/binary') }
      end # /context with a resource parent

      context 'with a path parent' do
        recipe do
          r = poise_test 'first' do
            mylang '/other'
          end
          poise_test 'test' do
            mylang_from_parent r
          end
        end

        it { is_expected.to run_poise_test('test').with(parent_mylang: nil, mylang: '/other') }
      end # /context with a path parent
    end # /describe #$name_from_parent

    context 'as a method' do
      resource(:poise_test) do
        include Module.new {
          include PoiseLanguages::Command::Mixin::Resource(:mylang)
        }
      end
      recipe do
        mylang_runtime 'parent'
        poise_test 'test'
      end

      it { is_expected.to run_poise_test('test').with(parent_mylang: runtime, mylang: '/binary') }
    end # /context as a method
  end # /describe PoiseLanguages::Command::Mixin::Resource

  describe PoiseLanguages::Command::Mixin::Provider do
    resource(:poise_test) do
      include PoiseLanguages::Command::Mixin::Resource(:mylang)
      include Poise::Helpers::LWRPPolyfill
      attribute(:command)
      attribute(:expect)
      attribute(:options, default: [])
    end

    describe '#$name_shell_out' do
      provider(:poise_test) do
        klass = described_class
        include Module.new {
          include klass
          language_command_mixin(:mylang)
        }
        def action_run
          expect(self).to receive(:shell_out).with(*new_resource.expect)
          mylang_shell_out(new_resource.command, *new_resource.options)
        end
      end

      context 'with a parent' do
        recipe do
          mylang_runtime 'parent'
          poise_test 'test' do
            command 'foo'
            expect ['/binary foo', {environment: {'MYLANG_PATH' => '/thing'}, timeout: 900}]
          end
        end
        it { run_chef }
      end # /context with a parent

      context 'without a parent' do
        recipe do
          poise_test 'test' do
            command 'foo'
            expect ['/which/mylang foo', {environment:{}, timeout: 900}]
          end
        end
        it { run_chef }
      end # /context without a parent

      context 'with a timeout' do
        recipe do
          mylang_runtime 'parent'
          poise_test 'test' do
            timeout 300
            command 'foo'
            expect ['/binary foo', {environment: {'MYLANG_PATH' => '/thing'}, timeout: 300}]
          end
        end
        it { run_chef }
      end # /context with a timeout

      context 'with environment options' do
        recipe do
          mylang_runtime 'parent'
          poise_test 'test' do
            command 'foo'
            options [{environment: {'OTHER' => 'foo'}}]
            expect ['/binary foo', {environment: {'MYLANG_PATH' => '/thing', 'OTHER' => 'foo'}, timeout: 900}]
          end
        end
        it { run_chef }
      end # /context with environment options

      context 'with an array command' do
        recipe do
          poise_test 'test' do
            command ['foo']
            expect [['/which/mylang', 'foo'], {environment: {}, timeout: 900}]
          end
        end
        it { run_chef }
      end # /context with an array command
    end # /describe #$name_shell_out

    describe '#$name_shell_out!' do
      provider(:poise_test) do
        klass = described_class
        include Module.new {
          include klass
          language_command_mixin(:mylang)
        }
        def action_run
          fake_output = double()
          expect(fake_output).to receive(:error!)
          expect(self).to receive(:mylang_shell_out).with(*new_resource.expect).and_return(fake_output)
          mylang_shell_out!(new_resource.command, *new_resource.options)
        end
      end
      recipe do
        poise_test 'test' do
          command 'foo'
          expect ['foo']
        end
      end

      it { run_chef }
    end # /describe #$name_shell_out!
  end # /describe PoiseLanguages::Command::Mixin::Provider
end
