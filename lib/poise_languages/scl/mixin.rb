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

require 'poise_languages/scl/resource'


module PoiseLanguages
  module Scl
    module Mixin
      private

      def install_scl_package
        pkg = scl_package
        poise_languages_scl pkg[:name] do
          parent new_resource
          url pkg[:url]
        end
      end

      def uninstall_scl_package
        install_scl_package.tap do |r|
          r.action(:uninstall)
        end
      end

      def scl_package
        @scl_package ||= self.class.find_scl_package(node, options['version']).tap do |p|
          raise PoiseLanguages::Error.new("No SCL repoistory package for #{node['platform']} #{node['platform_version']}") unless p
        end
      end

      def scl_folder
        ::File.join('', 'opt', 'rh', scl_package[:name])
      end

      def scl_environment
        parse_enable_file(::File.join(scl_folder, 'enable'))
      end

      # Parse an SCL enable file to extract the environment variables set in it.
      #
      # @param path [String] Path to the enable file.
      # @return [Hash<String, String>]
      def parse_enable_file(path)
        # Doesn't exist yet, so running Python will fail anyway. Just make sure
        # it fails in the expected way.
        return {} unless File.exist?(path)
        # Yes, this is a bash parser in regex. Feel free to be mad at me.
        IO.readlines(path).inject({}) do |memo, line|
          if match = line.match(/^export (\w+)=(.*)$/)
            memo[match[1]] = match[2].gsub(/\$\{(\w+)(:\+:\$\{\w+\})?\}/) do
              if $2
                ENV[$1] ? ":#{ENV[$1]}" : ''
              else
                ENV[$1].to_s
              end
            end
          end
          memo
        end
      end

      module ClassMethods
        def provides_auto?(node, resource)
          version = inversion_options(node, resource)['version']
          !!find_scl_package(node, version)
        end

        def scl_packages
          @scl_packages ||= []
        end

        def scl_package(version, name, urls)
          scl_packages << {version: version, name: name, urls: urls}
        end

        def find_scl_package(node, version)
          pkg = scl_packages.find {|p| p[:version].start_with?(version) }
          return unless pkg
          pkg[:url] = node.value_for_platform(pkg[:urls])
          return unless pkg[:url]
          pkg
        end

        def included(klass)
          super
          klass.extend(ClassMethods)
        end
      end

      extend ClassMethods

    end
  end
end
