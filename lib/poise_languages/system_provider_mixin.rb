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


module PoiseLanguages
  # A mixin to help write providers for language cookbooks (poise-ruby,
  # poise-python) that install from system packages.
  #
  # @since 1.0.0
  # @example
  #   module PoisePython
  #     module PythonProviders
  #       class System < Base
  #         include PoiseLanguages::SystemProviderMixin
  #         provides(:system)
  #         packages('python', {
  #           # ...
  #         })
  #       end
  #     end
  #   end
  module SystemProviderMixin
    # `install` action for system package providers.
    #
    # @return [void]
    def action_install
      action = options['package_upgrade'] ? :upgrade : :install
      run_package_action(package_name, options['version'], action)
    end

    # `uninstall` action for system package providers.
    #
    # @return [void]
    def action_uninstall
      action = node.platform_family?('debian') ? :purge : :remove
      run_package_action(package_name, options['version'], action, check_version: false)
    end

    private

    # Compute the package name for the development headers.
    #
    # @param package_name [String] Package name.
    # @return [String]
    def dev_package_name(package_name)
      return options['dev_package'] if options['dev_package'].is_a?(String)
      suffix = node.value_for_platform_family(debian: '-dev', rhel: '-devel', fedora: '-devel')
      # Platforms like Arch and Gentoo don't need this anyway. I've got no
      # clue how Amazon Linux does this.
      return unless suffix
      package_name + suffix
    end

    def package_resource(package_name, extra_packages: {})
      packages = {package_name => options['package_version']}
      if options['dev_package'] && d = dev_package_name(package_name)
        packages[d] = options['package_version']
      end
      packages.update(extra_packages)

      Chef::Log.debug("[#{new_resource}] Building package resource using #{packages.inspect}.")
      @package_resource ||= if node.platform_family?('rhel', 'fedora', 'amazon')
        # @todo Can't use multi-package mode with yum pending https://github.com/chef/chef/issues/3476
        packages.map do |name, version|
          Chef::Resource::Package.new(name, run_context).tap do |r|
            r.version(version)
          end
        end
      else
        Chef::Resource::Package.new(packages.keys, run_context).tap do |r|
          r.version(packages.values)
        end
      end
    end

    def run_package_action(package_name, version, action, check_version: true)
      resources = package_resource(package_name)
      # Support multiple packages if needed.
      Array(resources).each do |resource|
        # Reset it so we have a clean baseline.
        resource.updated_by_last_action(false)
        # Grab the provider.
        provider = resource.provider_for_action(action)
        # Check the candidate version if needed
        patch_load_current_resource!(provider, version) if check_version
        # Run our action.
        Chef::Log.debug("[#{new_resource}] Running #{provider} with #{action}")
        provider.run_action(action)
        # Check updated flag.
        new_resource.updated_by_last_action(true) if resource.updated_by_last_action?
      end
    end

    # Hack a provider object to run our verification code.
    #
    # @param provider [Chef::Provider] Provider object to patch.
    # @param version [String] Language version to check for.
    # @return [void]
    def patch_load_current_resource!(provider, version)
      # Create a closure module and inject it.
      provider.extend Module.new do
        # Patch load_current_resource to run our verification logic after
        # the normal code.
        define_method(:load_current_resource) do
          super().tap do |val|
            unless candidate_version_array.first && candidate_version_array.first.start_with?(version)
              raise PoiseLanguages::Error.new("Package #{package_name_array.first} would install #{candidate_version_array.first}, which does not match #{version}. Please set the package_name or package_version provider options.")
            end
          end
        end
      end
    end

    def package_name
      # If manually set, use that.
      return options['package_name'] if options['package_name']
      # Find package names known to exist.
      known_packages = package_names
      # version nil -> ''.
      version = options['version'] || ''
      # Find the first value on candidate_names that is in known_packages.
      candiate_names(version).each do |name|
        return name if known_packages.include?(name)
      end
      # No valid candidate. Sad trombone.
      raise PoiseLanguages::Error.new("Unable to find a candidate package for version #{version.inspect}. Please set package_name provider options.")
    end

    # Compute all possible package names for a given language version. Must be
    # implemented by mixin users. Versions are expressed as prefixes so ''
    # matches all versions, '2' matches 2.x.
    #
    # @abstract
    # @param version [String] Language version.
    # @return [Array<String>]
    def candiate_names(version)
      raise NotImplementedError
    end

    # Find all system packages available for this language on this platform.
    #
    # @return [Array<String>]
    def package_names
      names = node.value_for_platform(self.class.packages)
      if !names && self.class.default_package
        Chef::Log.debug("[#{new_resource}] No known packages for #{node['platform']} #{node['platform_version']}, defaulting to '#{self.class.default_package}'.")
        names = [self.class.default_package]
      end
      names
    end

    module ClassMethods
      def provides_auto?(node, resource)
        node.platform_family?('debian', 'rhel', 'amazon', 'fedora')
      end

      def default_inversion_options(node, resource)
        super.merge({
          # Install dev headers?
          dev_package: true,
          # Manual overrides for package name and/or version.
          package_name: nil,
          package_version: nil,
          # Set to true to use action :upgrade on all packages.
          package_upgrade: false,
        })
      end

      def packages(default_package=nil, packages=nil)
        self.default_package(default_package) if default_package
        if packages
          @packages = packages
        end
        @packages
      end

      def default_package(name=nil)
        if name
          @default_package = name
        end
        @default_package
      end

      def included(klass)
        super
        klass.extend(ClassMethods)
      end
    end

    extend ClassMethods

  end
end
