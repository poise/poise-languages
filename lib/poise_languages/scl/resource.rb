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

require 'chef/resource'
require 'chef/provider'
require 'poise'


module PoiseLanguages
  module Scl
    # A `poise_language_scl` resource to manage installing a language from
    # SCL packages. This is an internal implementation detail of
    # poise-languages.
    #
    # @api private
    # @since 1.0
    # @provides poise_languages_scl
    # @action install
    # @action uninstall
    class Resource < Chef::Resource
      include Poise
      provides(:poise_languages_scl)
      actions(:install, :uninstall)

      # @!attribute package_name
      #   Name of the SCL package for the language.
      #   @return [String]
      attribute(:package_name, kind_of: String, name_attribute: true)
      # @!attribute url
      #   URL to the SCL repository package for the language.
      #   @return [String]
      attribute(:url, kind_of: String, required: true)
      # @!attribute parent
      #   Resource for the language runtime. Used only for messages.
      #   @return [Chef::Resource]
      attribute(:parent, kind_of: Chef::Resource, required: true)
    end

    # The default provider for `poise_languages_scl`.
    #
    # @api private
    # @since 1.0
    # @see Resource
    # @provides poise_languages_scl
    class Provider < Chef::Provider
      include Poise
      provides(:poise_languages_scl)

      # The `install` action for the `poise_languages_scl` resource.
      #
      # @return [void]
      def action_install
        notifying_block do
          install_scl_utils
          install_scl_repo_package
          install_scl_package
        end
      end

      # The `uninstall` action for the `poise_languages_scl` resource.
      #
      # @return [void]
      def action_uninstall
        notifying_block do
          uninstall_scl_utils
          uninstall_scl_repo_package
          uninstall_scl_package
        end
      end

      private

      def install_scl_utils
        package 'scl-utils' do
          action :upgrade # This shouldn't be a problem. Famous last words.
        end
      end

      def install_scl_repo_package
        rpm_package 'rhscl-' + new_resource.package_name do
          source new_resource.url
        end
      end

      def install_scl_package
        yum_package new_resource.package_name do
          flush_cache before: true
        end
      end

      def uninstall_scl_utils
        install_scl_utils.tap do |r|
          r.action(:remove)
        end
      end

      def uninstall_scl_repo_package
        install_scl_repo_package.tap do |r|
          r.action(:remove)
        end
      end

      def uninstall_scl_package
        install_scl_package.tap do |r|
          r.action(:remove)
        end
      end

    end
  end
end
