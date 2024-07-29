# frozen_string_literal: true

require 'fileutils'
require "railsui/user_setup"

module Railsui
  module ThemeSetup
    include Railsui::UserSetup

    # gems
    def install_gems
      gem "railsui_icon"
      run "rails g railsui_icon:install"
      gem "meta-tags"
      gem "devise"
      gem "name_of_person"
    end

    # Assets
    def copy_theme_javascript(theme)
      say("Adding theme-specific stimulus.js controllers", :yellow)

      # Define paths
      source_path = "themes/#{theme}/javascript/controllers/railsui"
      destination_path = "app/javascript/controllers/railsui"
      index_js_path = Rails.root.join("app/javascript/controllers/index.js")

      # Copy the directory
      directory source_path, destination_path, force: true

      # Get the list of controller files
      controller_files = Dir.children(Rails.root.join(destination_path)).select { |f| f.end_with?("_controller.js") }
      puts "Controller files: 🗄️ #{controller_files}"

      # Generate import and register statements
      import_statements = controller_files.map do |file|
        controller_name = File.basename(file, ".js").sub("_controller", "")
        import_name = controller_name.camelize
        registration_name = controller_name.dasherize
        "import #{import_name}Controller from \"./railsui/#{File.basename(file, '.js')}\";\napplication.register(\"#{registration_name}\", #{import_name}Controller);"
      end.join("\n")

      # Read the existing index.js content
      index_js_content = File.exist?(index_js_path) ? File.read(index_js_path) : ""

      # Remove old import and register statements for railsui controllers
      new_index_js_content = index_js_content.gsub(/import .* from "\.\/railsui\/.*";\napplication\.register\(".*", .*;\n*/, "")

      # Add the new import and register statements
      new_index_js_content += "#{import_statements}\n"

      # Write the updated content back to index.js
      File.write(index_js_path, new_index_js_content)
      say("Updated app/javascript/controllers/index.js successfully.", :green)
    end

    def copy_theme_stylesheets(theme)
      say("Copying theme-specific stylesheets", :yellow)

      # Define paths
      source_path = "themes/#{theme}/stylesheets/railsui"
      destination_path = "app/assets/stylesheets/railsui"
      application_css_path = Rails.root.join("app/assets/stylesheets/application.tailwind.css")

      # Empty the destination directory before copying
      FileUtils.rm_rf(Dir.glob("#{destination_path}/*"))

      # Copy the directory and overwrite if theme is modified
      directory source_path, destination_path, force: true

      # Get the list of stylesheet files
      stylesheet_files = Dir.children(Rails.root.join(destination_path)).select { |f| f.end_with?(".css") }
      puts "Stylesheet files: 🗄️ #{stylesheet_files}"

      # Generate import statements for stylesheets
      import_statements = stylesheet_files.map do |file|
        "@import \"railsui/#{File.basename(file, '.css')}\";"
      end.join("\n")

      # Read the existing application.tailwind.css content
      application_css_content = File.exist?(application_css_path) ? File.read(application_css_path) : ""

      # Define the desired Tailwind structure
      tailwind_imports_top = [
        '@import "tailwindcss/base";',
        '@import "tailwindcss/components";'
      ].join("\n")

      tailwind_imports_bottom = '@import "tailwindcss/utilities";'

      # Remove old @tailwind directives and import statements for tailwindcss and railsui stylesheets
      cleaned_css_content = application_css_content.gsub(/@tailwind\s+(base|components|utilities);\n*/, "")
      cleaned_css_content.gsub!(/@import "tailwindcss\/.*";\n*/, "")
      cleaned_css_content.gsub!(/@import "railsui\/.*";\n*/, "")

      # Add the new import statements in the correct order
      new_application_css_content = [
        tailwind_imports_top,
        cleaned_css_content.strip,  # Preserving existing content
        import_statements,
        tailwind_imports_bottom
      ].join("\n")

      # Write the updated content back to application.tailwind.css
      File.write(application_css_path, new_application_css_content)
      say("Updated app/assets/stylesheets/application.tailwind.css successfully.", :green)
    end

    def install_theme_dependencies(theme)
      say("Installing dependencies", :yellow)
      add_yarn_packages(theme_dependencies(theme))
    end

     def install_action_text
      rails_command "action_text:install"

    end

    def setup_stimulus(theme)
      say("Setting up Stimulus controllers", :yellow)
      insert_stimulus_controllers
    end

    def update_tailwind_config(theme)
      say("Updating Tailwind CSS configuration", :yellow)
      copy_tailwind_config(theme)
    end

    def remove_action_text_defaults
      say "Remove default ActionText CSS"
      remove_file "app/assets/stylesheets/actiontext.css"

      gsub_file "app/assets/stylesheets/application.tailwind.css", /@import 'actiontext.css';/, ""
    end

    def humanize_theme(theme)
      theme.humanize
    end

    def theme_dependencies(theme)
      case theme
      when "hound"
        ["@tailwindcss/forms", "@tailwindcss/typography", "apexcharts", "autoprefixer", "postcss", "postcss-import", "postcss-nesting", "railsui-stimulus", "railsui-tailwind-presets", "stimulus-use", "tailwind-scrollbar", "tailwindcss", "tippy.js"]
      when "shepherd"
        ["@tailwindcss/forms", "@tailwindcss/typography", "apexcharts", "autoprefixer", "flatpickr", "hotkeys-js", "photoswipe", "postcss", "postcss-import", "postcss-nesting", "railsui-stimulus", "railsui-tailwind-presets", "stimulus-use", "tailwindcss", "tippy.js"]
      when "retriever"
        ["@tailwindcss/forms", "@tailwindcss/typography", "apexcharts", "autoprefixer", "flatpickr", "postcss", "postcss-import", "postcss-nesting", "railsui-stimulus", "railsui-tailwind-presets", "stimulus-use", "tailwind-scrollbar", "tailwindcss", "tippy.js"]
      when "setter"
        ["@tailwindcss/forms", "@tailwindcss/typography", "autoprefixer", "postcss", "postcss-import", "postcss-nesting", "railsui-stimulus", "railsui-tailwind-presets", "stimulus-use", "tailwind-scrollbar", "tailwindcss", "tippy.js"]
      else
        ["@tailwindcss/forms", "@tailwindcss/typography", "autoprefixer", "postcss", "postcss-import", "postcss-nesting", "railsui-stimulus", "railsui-tailwind-presets", "stimulus-use", "tailwind-scrollbar", "tailwindcss", "tippy.js"]
      end
    end

    def add_yarn_packages(packages)
      run "yarn add #{packages.join(' ')} --latest"
    end

    def insert_stimulus_controllers
      js_content = <<-JAVASCRIPT.strip_heredoc
        import { RailsuiClipboard, RailsuiCountUp, RailsuiDateRangePicker, RailsuiDropdown, RailsuiModal, RailsuiTabs, RailsuiToast, RailsuiToggle, RailsuiTooltip } from 'railsui-stimulus'

        application.register('railsui-clipboard', RailsuiClipboard)
        application.register('railsui-count-up', RailsuiCountUp)
        application.register('railsui-date-range-picker', RailsuiDateRangePicker)
        application.register('railsui-dropdown', RailsuiDropdown)
        application.register('railsui-modal', RailsuiModal)
        application.register('railsui-tabs', RailsuiTabs)
        application.register('railsui-toast', RailsuiToast)
        application.register('railsui-toggle', RailsuiToggle)
        application.register('railsui-tooltip', RailsuiTooltip)
      JAVASCRIPT

      insert_into_file "#{Rails.root}/app/javascript/controllers/index.js", "\n#{js_content}", after: 'import { application } from "./application"'
    end

    def copy_tailwind_config(theme)
      tailwind_config_path = Rails.root.join("tailwind.config.js")
      postcss_config_path = Rails.root.join("postcss.config.js")

      unless File.exist?(postcss_config_path)
        copy_file "postcss.config.js", postcss_config_path, force: true
      end

      if File.exist?(tailwind_config_path)
        content = File.read(tailwind_config_path)

        # Setup variables
        tailwind_setup = <<-JAVASCRIPT.strip_heredoc
          const presets = require("railsui-tailwind-presets");
          const execSync = require("child_process").execSync;
          const outputRailsUI = execSync("bundle show railsui", { encoding: "utf-8" });
          const rails_ui_path = outputRailsUI.trim() + "/**/*.rb";
          const rails_ui_template_path = outputRailsUI.trim() + "/**/*.html.erb";
        JAVASCRIPT

        tailwind_preset_content = "  presets: [presets.#{theme}],"

        # Combine the paths
        combined_paths_js = <<-JAVASCRIPT.strip_heredoc
          rails_ui_path,
          rails_ui_template_path,
          './app/components/**/*.rb',
          './app/components/**/*.html.erb',
          './app/helpers/**/*.rb',
          './app/javascript/**/*.js',
          './app/views/**/*.html.erb',
          './app/assets/stylesheets/**/*.css',
          "./config/initializers/railsui_icon.rb",
        JAVASCRIPT

        # Insert setup variables if not present
        unless content.include?(tailwind_setup)
          puts "Adding setup variables..."
          content.sub!("module.exports = {", "#{tailwind_setup}\nmodule.exports = {")
        end

        # Update or add the preset theme
        if content =~ /presets: \[presets\..+\],/
          content.gsub!(/presets: \[presets\..+\],/, tailwind_preset_content)
          puts "Updating preset theme to #{theme}..."
        else
          puts "Adding preset theme #{theme}..."
          content.sub!("module.exports = {", "module.exports = {\n#{tailwind_preset_content}")
        end

        # Add combined paths to the content array without duplication
        if content.include?("content: [")
          existing_paths = content.match(/content: \[([^\]]*)\]/m)[1].split(",").map(&:strip)
          new_paths = combined_paths_js.strip.split(",").map(&:strip)
          all_paths = (existing_paths + new_paths).uniq.sort

          formatted_paths = all_paths.map { |path| "    #{path}" }.join(",\n")

          content.sub!(/content: \[([^\]]*)\]/m, "content: [\n#{formatted_paths}\n  ]")
          puts "Adding combined paths..."
        else
          puts "Adding content array with combined paths..."
          content.sub!("module.exports = {", "module.exports = {\n  content: [\n#{combined_paths_js.strip.split(",").map { |path| "    #{path.strip}" }.join(",\n")}\n  ],")
        end

        # Write the updated content back to the file
        File.write(tailwind_config_path, content)
        puts "Updated tailwind.config.js successfully."
      else
        puts "No tailwind.config.js file. Creating one..."
        copy_file "themes/#{theme}/tailwind.config.js", tailwind_config_path, force: true
      end
    end

    # Mailers
    def generate_sample_mailers(theme)
      say "Adding Rails UI mailers", :yellow

      rails_command "generate mailer Railsui minimal promotion transactional"

      copy_sample_mailers(theme)

      insert_into_file Rails.root.join("app/mailers/railsui_mailer.rb").to_s, '  layout "railsui/railsui_mailer"', after: "class RailsuiMailer < ApplicationMailer\n"
    end

    def copy_sample_mailers(theme)
      source_directory = "themes/#{theme}/mail/railsui_mailer"
      destination_directory = Rails.root.join("app/views/railsui_mailer")
      directory source_directory, destination_directory, force: true
    end

    def update_railsui_mailer_layout(theme)
      source_file = Rails.root.join('app/views/layouts/rui/railsui_mailer.html.erb')
      if File.exist?(source_file)
        remove_file source_file
      end

      copy_file "themes/#{theme}/views/layouts/rui/railsui_mailer.html.erb", source_file, force: true
    end

    def update_application_mailer
      content = <<-RUBY.strip_heredoc
      helper Railsui::MailHelper
      RUBY

      insert_into_file "#{Rails.root}/app/mailers/application_mailer.rb", "  #{content}\n", after: "class ApplicationMailer < ActionMailer::Base\n"
    end

    # Routes
    def copy_railsui_routes
  content = <<-RUBY
  if Rails.env.development?
    mount Railsui::Engine, at: "/railsui"
  end

  # Inherits from Railsui::PageController#index
  # To override, add your own page#index view or change to a new root
  # Visit the start page for Rails UI any time at /railsui/start
  root action: :index, controller: "railsui/default"
  RUBY

      insert_into_file "#{Rails.root}/config/routes.rb", "\n#{content}\n", after: "Rails.application.routes.draw do\n", force: true
    end

    def copy_railsui_pages_routes
      routes_file = Rails.root.join('config/routes.rb')

      # Define the regex pattern for the `railsui` namespace block
      namespace_pattern = /^\s*namespace :railsui do.*?end\n/m

      # Generate new routes content based on the active pages
      new_routes = Railsui::Pages.theme_pages.keys.map do |page|
        "    get '#{page}', to: 'pages##{page}'"
      end.join("\n")

      # Define the routes block to be inserted within the namespace
      routes_block = "\n  namespace :rui do\n#{new_routes}\n  end\n"

      # Read the current content of the routes file
      route_content = File.read(routes_file)

      if route_content.match?(namespace_pattern)
        # Remove the existing `railsui` namespace block if present
        gsub_file routes_file, namespace_pattern, ''
      end

      # Append the new routes block at the end of the file if not present
      insert_into_file routes_file, routes_block, after: "Rails.application.routes.draw do\n", force: true
    end

    # Pages
    def copy_railsui_page_controller(theme)
      copy_file "themes/#{theme}/controllers/rui/pages_controller.rb", "app/controllers/rui/pages_controller.rb", force: true
    end

    def copy_railsui_pages(theme)
      Railsui::Pages.theme_pages.each do | page, details |
        if Railsui::Pages.page_enabled?(page) && !Railsui::Pages.page_exists?(page)
          copy_file "themes/#{theme}/views/rui/pages/#{page}.html.erb", "app/views/rui/pages/#{page}.html.erb", force: true
        end
      end

      copy_file "themes/#{theme}/views/layouts/rui/railsui.html.erb", "app/views/layouts/rui/railsui.html.erb", force: true
    end

    def update_body_classes
      layout_file = Rails.root.join("app/views/layouts/application.html.erb")

      if File.exist?(layout_file)
        # Read the entire layout file
        layout_content = File.read(layout_file)

        # Check if the body tag already has the helper
        if layout_content.include?('<%= railsui_body_classes %>')
          say("Body classes helper already added.", :yellow)
        else
          # Append the railsui_body_classes helper to the body tag
          updated_content = layout_content.gsub(
            /<body([^>]*)class="([^"]*)"/,
            '<body\1class="\2 <%= railsui_body_classes %>"'
          )

          # Write the updated content back to the layout file
          File.open(layout_file, "w") { |file| file.write(updated_content) }

          say("Body classes updated successfully.", :yellow)
        end
      else
        say("Layout file not found!", :red)
      end
    end

    def copy_railsui_head(theme)
      layout_file = "app/views/layouts/application.html.erb"
      return unless File.exist?(layout_file)

      unless File.read(layout_file).include?('<%= railsui_head %>')
    content = <<-ERB
    <%= railsui_head %>
    ERB
        insert_into_file layout_file, "\n#{content}", before: '</head>'
      end
    end

    def copy_railsui_launcher(theme)
      layout_file = "app/views/layouts/application.html.erb"
      return unless File.exist?(layout_file)

      unless File.read(layout_file).include?('<%= railsui_launcher if Rails.env.development? %>')
    content = <<-ERB
    <%= railsui_launcher if Rails.env.development? %>
    ERB
        insert_into_file layout_file, "\n#{content}", before: '</body>'
      end
    end

    def copy_railsui_images(theme)
      # Define paths
      theme_images_dir = "themes/#{theme}/images/railsui"
      target_images_dir = Rails.root.join("app/assets/images/railsui")

      # Remove existing target directory
      remove_directory(target_images_dir, "images")
      # add new images based on theme passed
      directory theme_images_dir, target_images_dir, force: true
    end

    def copy_railsui_shared_directory(theme)
      theme_dir = "themes/#{theme}/views/rui/shared"
      target_dir = Rails.root.join("app/views/rui/shared")

      remove_directory(target_dir, "shared views")
      directory theme_dir, target_dir, force: true
    end

    private

    def remove_directory(directory_path, thing)
      if Dir.exist?(directory_path)
        FileUtils.rm_rf(directory_path)
        say("Removed existing #{thing} in #{directory_path}")
      end
    rescue => e
      say("Error removing directory #{directory_path}: #{e.message}", :red)
      raise e
    end

    def remove_route(file, page)
      # Read the current content of the routes file
      route_content = File.read(file)

      # Remove route associated with railsui/pages#<page>
      route_content.gsub!(/^\s*get\s+'#{page}',\s+to:\s+'railsui\/pages##{page}'\s*$/, '')

      # Write the updated content back to the file
      File.open(file, 'w') { |f| f.write(route_content) }
    end
  end
end
