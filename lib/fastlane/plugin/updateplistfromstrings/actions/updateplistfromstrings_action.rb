module Fastlane
  module Actions
    class UpdateplistfromstringsAction < Action
      def self.run(params)
        input_file = params[:translations_source_file]
        target_file = params[:info_plist_strings_target_file]
        target_file_tmp = target_file + ".UpdateplistfromstringsAction.tmp"
        managed_marker = params[:managed_value_marker]
        key_map = params[:string_key_map]
        use_key_for_empty_value = params[:use_source_key_for_empty_values]
        set_in_plist = params[:set_values_in_info_plist]
        plist_path = params[:plist_path]
        omit_if_empty_value = params[:omit_if_value_empty]

        raise "Must provide a value for :plist_path if :set_in_plist is true" if set_in_plist and plist_path == ""

        # Preserve the non-managed lines:
        non_managed_lines = []

        if File.exist?(target_file)
          open(target_file, encoding: 'bom|utf-8') do |f|
            f.each_line do |line|
              non_managed_lines << line.strip unless /#{managed_marker}/.match?(line)
            end
          end
        end

        # Build the managed lines, and set Info.plist key/values.
        managed_lines = []
        managed_target_keys = []
        open(input_file, encoding: 'bom|utf-8') do |f|
          f.each_line do |line|
            key_map.each do |target_key, source_key|
              regex = /^"#{source_key}"\s*=\s*"(?<value>.*)"\s*;\s*$/
              matches = line.match(regex)
              next unless matches
              next if omit_if_empty_value and matches['value'].empty?

              quoted_source_key = %("#{source_key}")
              target_line = line.sub(quoted_source_key, target_key).strip
              if use_key_for_empty_value and matches['value'].empty?
                value = source_key
                target_line.sub!(/"";$/, quoted_source_key + ";")
              else
                value = matches['value']
              end
              target_line += "  /* #{managed_marker} */"
              managed_lines << target_line
              managed_target_keys << target_key

              if set_in_plist
                UI.message "Setting in Info.plist: #{target_key} = #{value}"
                Fastlane::Actions::SetInfoPlistValueAction.run(path: plist_path, key: target_key, value: value)
              end
            end
          end
        end

        # Remove any non-managed lines that are now managed.
        non_managed_lines = non_managed_lines.reject do |line|
          managed_target_keys.find { |key| line.match(/^#{key}\s*=\s*".*"\s*;.*$/) }
        end

        IO.write(target_file_tmp, (non_managed_lines + managed_lines).join("\n") + "\n")
        FileUtils.mv(target_file_tmp, target_file, force: true)

        UI.message "#{managed_lines.length} managed translation values set in #{target_file}"
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Update InfoPlist.strings from translation file"
      end

      def self.details
        "Add / update selected translations from a source Localizable.strings file to a InfoPlist.strings file"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :translations_source_file,
                                       description: "Full path to translations file (used to extract the translation)"),
          FastlaneCore::ConfigItem.new(key: :info_plist_strings_target_file,
                                       description: "Full path to InfoPlist.strings file (which will have the translated values set)"),
          FastlaneCore::ConfigItem.new(key: :string_key_map,
                                       description: "A Hash of destination(InfoPlist.strings) keys => source(from translations_source_file) keys to use.  If a translation for the source key exists in the source file, the translation will be added / updated in the target file",
                                       is_string: false,
                                       default_value: {}),
          FastlaneCore::ConfigItem.new(key: :managed_value_marker,
                                       description: "A string that will be embedded in a comment on each translation line of the target file, to indicate that it is a fastlane-managed item",
                                       default_value: "fastlane_managed_value_marker"),
          FastlaneCore::ConfigItem.new(key: :omit_if_value_empty,
                                       description: "If true, and a key exists in the source file whose value is an empty string, do not add the values to the target file (and Info.plist, if :set_values_in_info_plist is true)",
                                       is_string: false,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :use_source_key_for_empty_values,
                                      description: "If true, and a key exists in the source file whose value is an empty string, the source file key will be used instead of an empty string when writing to the target file",
                                      is_string: false,
                                      default_value: true),
          FastlaneCore::ConfigItem.new(key: :set_values_in_info_plist,
                                      description: "If true, set the corresponding values in Info.plist.  If a fallback language has been specified by setting the app's CFBundleDevelopmentRegion, and it is certain that all translations are present for that language, this should be set to false",
                                      is_string: false,
                                      default_value: false),
          FastlaneCore::ConfigItem.new(key: :plist_path,
                                      description: "Path to Info.plist file",
                                      default_value: "")
        ]
      end

      def self.output
        []
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.authors
        ["brki", "jschmid"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
