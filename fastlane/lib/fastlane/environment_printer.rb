module Fastlane
  class EnvironmentPrinter
    def self.output
      env_info = get
      puts env_info
      if FastlaneCore::Helper.mac? && UI.interactive? && UI.confirm("🙄  Wow, that's a lot of markdown text... should fastlane put it into your clipboard, so you can easily paste it on GitHub?")
        copy_to_clipboard(env_info)
        UI.success("Successfully copied markdown into your clipboard 🎨")
      end
      UI.success("Open https://github.com/fastlane/fastlane/issues/new to submit a new issue ✅")
    end

    def self.get
      UI.important("Generating fastlane environment output, this might take a few seconds...")
      require "fastlane/markdown_table_formatter"
      env_output = ""
      env_output << print_system_environment
      env_output << print_system_locale
      env_output << print_fastlane_files
      env_output << print_loaded_fastlane_gems
      env_output << print_loaded_plugins
      env_output << print_loaded_gems
      env_output << print_date

      # Adding title
      status = (env_output.include?("🚫") ? "🚫" : "✅")
      env_header = "<details><summary>#{status} fastlane environment #{status}</summary>\n\n"
      env_tail = "</details>"
      final_output = ""

      if $captured_output
        final_output << "### Captured Output\n\n"
        final_output << "Command Used: `#{ARGV.join(' ')}`\n"
        final_output << "<details><summary>Output/Log</summary>\n\n```\n\n#{$captured_output}\n\n```\n\n</details>\n\n"
      end

      final_output << env_header + env_output + env_tail
    end

    def self.print_date
      date = Time.now.strftime("%Y-%m-%d")
      "\n*generated on:* **#{date}**\n"
    end

    def self.print_loaded_plugins
      ENV["FASTLANE_ENV_PRINTER"] = "enabled"
      env_output =  "### Loaded fastlane plugins:\n"
      env_output << "\n"
      plugin_manager = Fastlane::PluginManager.new
      plugin_manager.load_plugins
      if plugin_manager.available_plugins.length <= 0
        env_output << "**No plugins Loaded**\n"
      else
        table = ""
        table << "| Plugin | Version | Update-Status |\n"
        table << "|--------|---------|\n"
        plugin_manager.available_plugins.each do |plugin|
          begin
          installed_version = Fastlane::ActionCollector.determine_version(plugin)
          update_url = FastlaneCore::UpdateChecker.generate_fetch_url(plugin)
          latest_version = FastlaneCore::UpdateChecker.fetch_latest(update_url)
          if Gem::Version.new(installed_version) == Gem::Version.new(latest_version)
            update_status = "✅ Up-To-Date"
          else
            update_status = "🚫 Update availaible"
          end
        rescue
          update_status = "💥 Check failed"
        end
          table << "| #{plugin} | #{installed_version} | #{update_status} |\n"
        end

        rendered_table = MarkdownTableFormatter.new table
        env_output << rendered_table.to_md
      end

      env_output << "\n\n"
      env_output
    end

    # We have this as a separate method, as this has to be handled
    # slightly differently, depending on how fastlane is being called
    def self.gems_to_check
      if Helper.contained_fastlane?
        Gem::Specification
      else
        Gem.loaded_specs.values
      end
    end

    def self.print_loaded_fastlane_gems
      # fastlanes internal gems
      env_output = "### fastlane gems\n\n"
      table = ""
      table << "| Gem | Version | Update-Status |\n"
      table << "|-----|---------|------------|\n"
      fastlane_tools = Fastlane::TOOLS + [:fastlane_core, :credentials_manager]

      gems_to_check.each do |current_gem|
        update_status = "N/A"

        next unless fastlane_tools.include?(current_gem.name.to_sym)
        begin
          update_url = FastlaneCore::UpdateChecker.generate_fetch_url(current_gem.name)
          latest_version = FastlaneCore::UpdateChecker.fetch_latest(update_url)
          if Gem::Version.new(current_gem.version) == Gem::Version.new(latest_version)
            update_status = "✅ Up-To-Date"
          else
            update_status = "🚫 Update availaible"
          end
        rescue
          update_status = "💥 Check failed"
        end
        table << "| #{current_gem.name} | #{current_gem.version} | #{update_status} |\n"
      end

      rendered_table = MarkdownTableFormatter.new table
      env_output << rendered_table.to_md

      env_output << "\n\n"

      return env_output
    end

    def self.print_loaded_gems
      env_output = "<details>"
      env_output << "<summary><b>Loaded gems</b></summary>\n\n"

      table = "| Gem | Version |\n"
      table << "|-----|---------|\n"
      gems_to_check.each do |current_gem|
        unless Fastlane::TOOLS.include?(current_gem.name.to_sym)
          table << "| #{current_gem.name} | #{current_gem.version} |\n"
        end
      end
      rendered_table = MarkdownTableFormatter.new table

      env_output << rendered_table.to_md
      env_output << "</details>\n\n"
      return env_output
    end

    def self.print_system_locale
      env_output = "### System Locale\n\n"
      found_one = false
      env_table = ""
      ["LANG", "LC_ALL", "LANGUAGE"].each do |e|
        env_icon = "🚫"
        if ENV[e] && ENV[e].end_with?("UTF-8")
          env_icon = "✅"
          found_one = true
        end
        if ENV[e].nil?
          env_icon = ""
        end
        env_table << "| #{e} | #{ENV[e]} | #{env_icon} |\n"
      end
      if !found_one
        table = "| Error |\n"
        table << "|-----|\n"
        table << "| No Locale with UTF8 found 🚫|\n"
      else
        table = "| Variable | Value |  |\n"
        table << "|-----|---------|----|\n"
        table << env_table
      end
      rendered_table = MarkdownTableFormatter.new table
      env_output << rendered_table.to_md
      env_output << "\n\n"
    end

    def self.print_system_environment
      require "openssl"

      env_output = "### Stack\n\n"
      product, version, build = `sw_vers`.strip.split("\n").map { |line| line.split(':').last.strip }
      table_content = {
        "fastlane" => Fastlane::VERSION,
        "OS" => `sw_vers -productVersion`.strip,
        "Ruby" => RUBY_VERSION,
        "Bundler?" => Helper.bundler?,
        "Xcode Path" => Helper.xcode_path,
        "Xcode Version" => Helper.xcode_version,
        "Git" => `git --version`.strip.split("\n").first,
        "Installation Source" => $PROGRAM_NAME,
        "Host" => "#{product} #{version} (#{build})",
        "Ruby Lib Dir" => RbConfig::CONFIG['libdir'],
        "OpenSSL Version" => OpenSSL::OPENSSL_VERSION
      }
      table = ["| Key | Value |"]
      table += table_content.collect { |k, v| "| #{k} | #{v} |" }

      begin
        rendered_table = MarkdownTableFormatter.new(table.join("\n"))
        env_output << rendered_table.to_md
      rescue => ex
        UI.error(ex)
        UI.error("Error rendering markdown table using the following text:")
        UI.message(table.join("\n"))
        env_output << table.join("\n")
      end

      env_output << "\n\n"
      env_output
    end

    def self.print_fastlane_files
      env_output = "### fastlane files:\n\n"

      fastlane_path = FastlaneFolder.fastfile_path

      if fastlane_path && File.exist?(fastlane_path)
        env_output << "<details>"
        env_output << "<summary>`#{fastlane_path}`</summary>\n"
        env_output << "\n"
        env_output << "```ruby\n"
        env_output <<  File.read(fastlane_path)
        env_output <<  "```\n"
        env_output << "</details>"
      else
        env_output << "**No Fastfile found**\n"
      end
      env_output << "\n\n"

      appfile_path = CredentialsManager::AppfileConfig.default_path
      if appfile_path && File.exist?(appfile_path)
        env_output << "<details>"
        env_output << "<summary>`#{appfile_path}`</summary>\n"
        env_output << "\n"
        env_output << "```ruby\n"
        env_output <<  File.read(appfile_path)
        env_output <<  "```\n"
        env_output << "</details>"
      else
        env_output << "**No Appfile found**\n"
      end
      env_output << "\n\n"
      env_output
    end

    # Copy a given string into the clipboard
    # Make sure to ask the user first, as some people don't
    # use a clipboard manager, so they might lose something important
    def self.copy_to_clipboard(string)
      require 'open3'
      Open3.popen3('pbcopy') { |input, _, _| input << string }
    end
  end
end
