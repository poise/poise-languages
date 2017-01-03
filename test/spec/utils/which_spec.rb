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

describe PoiseLanguages::Utils::Which do
  let(:params) { [] }
  let(:executables) { {} }
  let(:env_path) { '' }
  subject { described_class.which(*params) }
  before do
    executables.each do |path, value|
      allow(File).to receive(:executable?).with(path).and_return(value)
    end
  end
  around do |ex|
    begin
      old_path = ENV['PATH']
      ENV['PATH'] = env_path
      ex.run
    ensure
      ENV['PATH'] = old_path
    end
  end

  context 'with no environment variable' do
    let(:params) { ['myapp'] }
    let(:executables) { {'/bin/myapp' => false, '/usr/bin/myapp' => false, '/sbin/myapp' => true} }
    it { is_expected.to eq '/sbin/myapp' }
  end # /context with no environment variable

  context 'with extra_path' do
    let(:params) { ['myapp', {extra_path: %w{/foo /bar}}] }
    let(:executables) { {'/foo/myapp' => false, '/bar/myapp' => true} }
    it { is_expected.to eq '/bar/myapp' }
  end # /context with extra_path

  context 'with $PATH' do
    let(:params) { ['myapp'] }
    let(:env_path) { %w{/something /other /nope}.join(File::PATH_SEPARATOR) }
    let(:executables) { {'/something/myapp' => false, '/other/myapp' => true} }
    it { is_expected.to eq '/other/myapp' }
  end # /context with $PATH

  context 'with path' do
    let(:params) { ['myapp', {path: %w{/something /other /nope}.join(File::PATH_SEPARATOR)}] }
    let(:executables) { {'/something/myapp' => false, '/other/myapp' => true} }
    it { is_expected.to eq '/other/myapp' }
  end # /context with path

  context 'with a non-existent command' do
    let(:params) { ['myapp'] }
    let(:executables) { {'/bin/myapp' => false, '/usr/bin/myapp' => false, '/sbin/myapp' => false, '/usr/sbin/myapp' => false} }
    it { is_expected.to be false }
  end # /context with a non-existent command

  context 'with an absolute Unix path' do
    let(:params) { ['/myapp'] }
    it { is_expected.to eq '/myapp' }
  end # /context with an absolute Unix path

  context 'with an absolute Windows path' do
    let(:params) { ['C:\\myapp'] }
    it { is_expected.to eq 'C:\\myapp' }
  end # /context with an absolute Windows path

  context 'with an absolute UNC path' do
    let(:params) { ['//myapp'] }
    it { is_expected.to eq '//myapp' }
  end # /context with an absolute UNC path
end
