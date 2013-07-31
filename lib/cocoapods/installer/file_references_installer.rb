module Pod
  class Installer

    # Controller class responsible of installing the file references of the
    # specifications in the Pods project.
    #
    class FileReferencesInstaller

      # @return [Sandbox] The sandbox of the installation.
      #
      attr_reader :sandbox

      # @return [Array<Library>] The libraries of the installation.
      #
      attr_reader :libraries

      # @return [Project] The Pods project.
      #
      attr_reader :pods_project

      # @param [Sandbox] sandbox @see sandbox
      # @param [Array<Library>] libraries @see libraries
      # @param [Project] libraries @see libraries
      #
      def initialize(sandbox, libraries, pods_project)
        @sandbox = sandbox
        @libraries = libraries
        @pods_project = pods_project
      end

      # Installs the file references.
      #
      # @return [void]
      #
      def install!
        refresh_file_accessors
        add_source_files_references
        add_frameworks_bundles
        add_library_files
        add_resources_bundles
        link_headers
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Installation Steps

      # Reads the file accessors contents from the file system.
      #
      # @note   The contents of the file accessors are modified by the clean
      #         step of the #{PodSourceInstaller} and by the pre install hooks.
      #
      # @return [void]
      #
      def refresh_file_accessors
        file_accessors.each do |fa|
          fa.path_list.read_file_system
        end
      end

      # Adds the source files of the Pods to the Pods project.
      #
      # @note   The source files are grouped by Pod and in turn by subspec
      #         (recursively).
      #
      # @note   Pods are generally added to the `Pods` group, however, if they
      #         have a local source they are added to the
      #         `Local Pods` group.
      #
      # @return [void]
      #
      def add_source_files_references
        UI.message "- Adding source files to Pods project" do
          add_file_acessors_paths_to_pods_group(:source_files, :source_files)
        end
      end

      # Adds the frameworks bundles to the Pods project
      #
      # @return [void]
      #
      def add_frameworks_bundles
        UI.message "- Adding frameworks to Pods project" do
          add_file_acessors_paths_to_pods_group(:framework_bundles, :frameworks_and_libraries)
        end
      end

      # TODO
      #
      def add_library_files
        UI.message "- Adding frameworks to Pods project" do
          add_file_acessors_paths_to_pods_group(:library_files, :frameworks_and_libraries)
        end
      end

      # Adds the resources of the Pods to the Pods project.
      #
      # @note   The source files are grouped by Pod and in turn by subspec
      #         (recursively) in the resources group.
      #
      # @return [void]
      #
      def add_resources_bundles
        UI.message "- Adding resources to Pods project" do
          add_file_acessors_paths_to_pods_group(:resources, :resources)
        end
      end

      # Creates the link to the headers of the Pod in the sandbox.
      #
      # @return [void]
      #
      def link_headers
        UI.message "- Linking headers" do
          libraries.each do |library|
            library.file_accessors.each do |file_accessor|
              headers_sandbox = Pathname.new(file_accessor.spec.root.name)
              library.build_headers.add_search_path(headers_sandbox)
              sandbox.public_headers.add_search_path(headers_sandbox)

              header_mappings(headers_sandbox, file_accessor, file_accessor.headers).each do |namespaced_path, files|
                library.build_headers.add_files(namespaced_path, files)
              end

              header_mappings(headers_sandbox, file_accessor, file_accessor.public_headers).each do |namespaced_path, files|
                sandbox.public_headers.add_files(namespaced_path, files)
              end
            end
          end
        end
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Private Helpers

      # @return [Array<Sandbox::FileAccessor>] The file accessors for all the
      #         specs platform combinations.
      #
      def file_accessors
        @file_accessors ||= libraries.map(&:file_accessors).flatten.compact
      end

      def add_file_acessors_paths_to_pods_group(paths_method, group_name)
        file_accessors.each do |file_accessor|
          paths = file_accessor.send(paths_method)
          paths.each do |path|
            group = pods_project.group_for_spec(file_accessor.spec.name, group_name)
            pods_project.add_file_reference(path, group)
            # group.new_file(pods_project.relativize(path))
          end
        end
      end

      # Computes the destination sub-directory in the sandbox
      #
      # @param  [Pathname] headers_sandbox
      #         The sandbox where the headers links should be stored for this
      #         Pod.
      #
      # @param  [Specification::Consumer] consumer
      #         The consumer for which the headers need to be linked.
      #
      # @param  [Array<Pathname>] headers
      #         The absolute paths of the headers which need to be mapped.
      #
      # @return [Hash{Pathname => Array<Pathname>}] A hash containing the
      #         headers folders as the keys and the absolute paths of the
      #         header files as the values.
      #
      def header_mappings(headers_sandbox, file_accessor, headers)
        consumer = file_accessor.spec_consumer
        dir = headers_sandbox
        dir = dir + consumer.header_dir if consumer.header_dir

        mappings = {}
        headers.each do |header|
          sub_dir = dir
          if consumer.header_mappings_dir
            header_mappings_dir = file_accessor.path_list.root + consumer.header_mappings_dir
            relative_path = header.relative_path_from(header_mappings_dir)
            sub_dir = sub_dir + relative_path.dirname
          end
          mappings[sub_dir] ||= []
          mappings[sub_dir] << header
        end
        mappings
      end

      #-----------------------------------------------------------------------#

    end
  end
end
