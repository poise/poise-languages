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

describe PoiseLanguages::Scl::Mixin do
  let(:klass) do
    mixin = described_class
    Class.new do
      include mixin
    end
  end

  describe '#parse_enable_file' do
    let(:content) { '' }
    before do
      allow(File).to receive(:exist?).with('/test/enable').and_return(true)
      allow(IO).to receive(:readlines).with('/test/enable').and_return(content.split(/\n/))
    end
    subject { klass.new.send(:parse_enable_file, '/test/enable') }

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
  end # /describe #parse_enable_file
end
