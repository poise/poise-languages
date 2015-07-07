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
  module System
    # A `poise_language_system` resource to manage installing a language from
    # system packages. This is an internal implementation detail of
    # poise-languages.
    #
    # @api private
    # @since 1.0
    # @provides poise_languages_system
    # @action install
    # @action upgrade
    # @action uninstall
    class Resource < Chef::Resource
      include Poise
      provides(:poise_languages_system)
      actions(:install, :upgrade, :uninstall)

      # @!attribute candidate_packages
      #   Array of potential candidate package names. This should be all
      #   that could potentially match the {version} prefix.
      #   @return [Array<String>]
      attribute(:candidate_packages, kind_of: Array, default: lazy { [] })
      # @!attribute dev_package
      #   Name of the development headers package, or false to disable
      #   installing headers. By default computed from {package_name}.
      #   @return [String, false]
      attribute(:dev_package, kind_of: [String, FalseClass], default: lazy { default_dev_package })
      # @!attribute package_name
      #   Name of the main package for the language. By default computed from
      #   {candidate_packages} and {system_packages}.
      #   @return [String]
      attribute(:package_name, kind_of: String, default: lazy { default_package_name })
      # @!attribute package_version
      #   Version of the package(s) to install. This is distinct from {version},
      #   and is the specific version package version, not the language version.
      #   By default this is unset meaning the latest version will be used.
      #   @return [String, nil]
      attribute(:package_version, kind_of: [String, NilClass])
      # @!attribute parent
      #   Resource for the language runtime. Used only for messages.
      #   @return [Chef::Resource]
      attribute(:parent, kind_of: Chef::Resource, required: true)
      # @!attribute system_packages
      #   Array of all packages that exist for this language on the current
      #   platform.
      #   @return [Array<String>]
      attribute(:system_packages, kind_of: Array, default: lazy { [] })
      # @!attributes version
      #   Language version prefix. This prefix determines which version of the
      #   language to install, following prefix matching rules.
      #   @return [String]
      attribute(:version, kind_of: String, default: '')

      # Compute the default package name for the language.
      #
      # @return [String]
      def default_package_name
        # Find the first value on candidate_packages that is in system_packages.
        candidate_packages.each do |name|
          return name if system_packages.include?(name)
        end
        # No valid candidate. Sad trombone.
        raise PoiseLanguages::Error.new("Unable to find a candidate package for version #{version.inspect}. Please set package_name provider option for #{parent}.")
      end

      # Compute the default package name for the development headers.
      #
      # @return [String]
      def default_dev_package
        suffix = node.value_for_platform_family(debian: '-dev', rhel: '-devel', fedora: '-devel')
        # Platforms like Arch and Gentoo don't need this anyway. I've got no
        # clue how Amazon Linux does this.
        if suffix
          package_name + suffix
        else
          nil
        end
      end
    end

    # The default provider for `poise_languages_system`.
    #
    # @api private
    # @since 1.0
    # @see Resource
    # @provides poise_languages_system
    class Provider < Chef::Provider
      include Poise
      provides(:poise_languages_system)

      # The `install` action for the `poise_languages_system` resource.
      #
      # @return [void]
      def action_install
        run_package_action(:install)
      end

      # The `upgrade` action for the `poise_languages_system` resource.
      #
      # @return [void]
      def action_upgrade
        run_package_action(:upgrade)
      end

      # The `uninstall` action for the `poise_languages_system` resource.
      #
      # @return [void]
      def action_uninstall
        action = node.platform_family?('debian') ? :purge : :remove
        package_resources.each do |resource|
          resource.run_action(action)
          new_resource.updated_by_last_action(true) if resource.updated_by_last_action?
        end
      end

      private

      # Create package resource objects for all needed packages. These are created
      # directly and not added to the resource collection.
      #
      # @return [Array<Chef::Resource::Package>]
      def package_resources
        packages = {new_resource.package_name => new_resource.package_version}
        # If we are supposed to install the dev package, grab it using the same
        # version as the main package.
        if new_resource.dev_package
          packages[new_resource.dev_package] = new_resource.package_version
        end

        Chef::Log.debug("[#{new_resource.parent}] Building package resource using #{packages.inspect}.")
        @package_resource ||= if node.platform_family?('rhel', 'fedora', 'amazon')
          # @todo Can't use multi-package mode with yum pending https://github.com/chef/chef/issues/3476.
          packages.map do |name, version|
            Chef::Resource::Package.new(name, run_context).tap do |r|
              r.version(version)
            end
          end
        else
          [Chef::Resource::Package.new(packages.keys, run_context).tap do |r|
            r.version(packages.values)
          end]
        end
      end

      # Run the requested action for all package resources. This exists because
      # we inject our version check in to the provider directly and I want to
      # only run the provider action once for performance. It is otherwise
      # mostly a stripped down version of Chef::Resource#run_action.
      #
      # @param action [Symbol] Action to run on all package resources.
      # @return [void]
      def run_package_action(action)
        package_resources.each do |resource|
          # Reset it so we have a clean baseline.
          resource.updated_by_last_action(false)
          # Grab the provider.
          provider = resource.provider_for_action(action)
          # Check the candidate version if needed
          patch_load_current_resource!(provider, new_resource.version)
          # Run our action.
          Chef::Log.debug("[#{new_resource.parent}] Running #{provider} with #{action}")
          provider.run_action(action)
          # Check updated flag.
          new_resource.updated_by_last_action(true) if resource.updated_by_last_action?
        end
      end

      # Hack a provider object to run our verification code.
      #
      # @param provider [Chef::Provider] Provider object to patch.
      # @param version [String] Language version prefix to check for.
      # @return [void]
      def patch_load_current_resource!(provider, version)
        # Create a closure module and inject it.
        provider.extend Module.new do
          # Patch load_current_resource to run our verification logic after
          # the normal code.
          define_method(:load_current_resource) do
            super().tap do |_|
              each_package do |package_name, new_version, current_version, candidate_version|
                unless candidate_version.start_with?(version)
                  raise PoiseLanguages::Error.new("Package #{package_name} would install #{candidate_version}, which does not match #{version.empty? ? version.inspect : version}. Please set the package_name or package_version provider options.")
                end
              end
            end
          end
        end
      end

    end
  end
end
