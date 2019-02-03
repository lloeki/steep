module Steep
  module Drivers
    class Annotations
      attr_reader :source_paths
      attr_reader :stdout
      attr_reader :stderr
      attr_reader :labeling

      include Utils::EachSignature

      def initialize(source_paths:, stdout:, stderr:)
        @source_paths = source_paths
        @stdout = stdout
        @stderr = stderr

        @labeling = ASTUtils::Labeling.new
      end

      def run
        project = Project.new()

        source_paths.each do |path|
          each_file_in_path(".rb", path) do |file_path|
            file = Project::SourceFile.new(path: file_path, options: Project::Options.new)
            file.content = file_path.read
            project.source_files[file_path] = file
          end
        end

        project.source_files.each_value do |file|
          file.parse
          file.source.each_annotation.sort_by {|node, _| [node.loc.expression.begin_pos, node.loc.expression.end_pos] }.each do |node, annotations|
            loc = node.loc
            stdout.puts "#{file.path}:#{loc.line}:#{loc.column}:#{node.type}:\t#{node.loc.expression.source.lines.first}"
            annotations.each do |annotation|
              stdout.puts "  #{annotation.location.source}"
            end
          end
        end

        0
      end
    end
  end
end
