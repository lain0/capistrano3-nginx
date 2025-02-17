git_plugin = self

namespace :nginx do
  task :load_vars do
    set :sites_available,       -> { fetch(:nginx_sites_available_dir) }
    set :sites_enabled,         -> { fetch(:nginx_sites_enabled_dir) }
    set :enabled_application,   -> { File.join(fetch(:sites_enabled),   fetch(:nginx_application_name)) }
    set :available_application, -> { File.join(fetch(:sites_available), fetch(:nginx_application_name)) }
  end



  # validate_sudo_settings
  task :validate_user_settings do
    path_and_dir_keys = [:nginx_log_path, :nginx_sites_enabled_dir, :nginx_sites_available_dir]
    nginx_task_keys   = ['nginx:start', 'nginx:stop', 'nginx:restart', 'nginx:reload', 'nginx:configtest', 'nginx:site:add', 'nginx:site:disable', 'nginx:site:enable', 'nginx:site:remove' ]

    fetch(:nginx_sudo_paths).each do | path |
      abort("Invalid value in :nginx_sudo_paths, Unknown symbol '#{path}'") unless path_and_dir_keys.include? path
    end
    fetch(:nginx_sudo_tasks).each do | task |
      abort("Invalid symbol in :nginx_tasks! Unknown symbol '#{task}'") unless nginx_task_keys.include? task
    end
  end

  desc "Configtest nginx"
  task :configtest do
    on release_roles fetch(:nginx_roles) do
      execute(
          "sudo nginx -t",
          interaction_handler: PasswdInteractionHandler.new
      )
    end
  end

  %w[start stop restart reload].each do |command|
    desc "#{command.capitalize} nginx service"
    task command => ['nginx:validate_user_settings'] do
      on release_roles fetch(:nginx_roles) do
        arguments = fetch(:nginx_service_path), command
        git_plugin.add_sudo_if_required arguments, "nginx:#{command}"
        execute *arguments, interaction_handler: PasswdInteractionHandler.new
      end
    end
    before "nginx:#{command}", 'nginx:configtest' unless command == 'stop'
  end

  task :create_log_paths do
    on release_roles fetch(:nginx_roles) do
      arguments = :mkdir, '-pv', fetch(:nginx_log_path)
      git_plugin.add_sudo_if_required arguments, :nginx_log_path
      execute *arguments, interaction_handler: PasswdInteractionHandler.new
    end
  end
  after 'deploy:check', 'nginx:create_log_paths' if fetch(:nginx_log_path)

  desc 'Compress JS and CSS with gzip'
  task :gzip_static => ['nginx:load_vars'] do
    on release_roles fetch(:nginx_roles) do
      within release_path do
        arguments = :find, "'#{fetch(:nginx_static_dir)}' -type f -name '*.js' -o -name '*.css' -exec gzip -v -9 -f -k {} \\;"
        git_plugin.add_sudo_if_required arguments, :gzip_static
        execute *arguments, interaction_handler: PasswdInteractionHandler.new
      end
    end
  end

  namespace :site do
    desc 'Creates the site configuration and upload it to the available folder'
    task :add => ['nginx:load_vars', 'nginx:validate_user_settings'] do
      on release_roles fetch(:nginx_roles) do
        within fetch(:sites_available) do
          config_file = fetch(:nginx_template)
          if config_file == :default
            config_file = File.expand_path('../../../../templates/nginx.conf.erb', __FILE__)
          end
          config = ERB.new(File.read(config_file)).result(binding)
          upload! StringIO.new(config), '/tmp/nginx.conf'
          arguments = :mv, '/tmp/nginx.conf', fetch(:nginx_application_name)
          git_plugin.add_sudo_if_required arguments, 'nginx:sites:add', :nginx_sites_available_dir
          execute *arguments, interaction_handler: PasswdInteractionHandler.new
        end
      end
    end

    desc 'Enables the site creating a symbolic link into the enabled folder'
    task :enable => ['nginx:load_vars', 'nginx:validate_user_settings'] do
      on release_roles fetch(:nginx_roles) do
        if test "! [ -h #{fetch(:enabled_application)} ]"
          within fetch(:sites_enabled) do
            arguments = :ln, '-nfs', fetch(:available_application), fetch(:enabled_application)
            git_plugin.add_sudo_if_required arguments, 'nginx:sites:enable', :nginx_sites_enabled_dir
            execute *arguments, interaction_handler: PasswdInteractionHandler.new
          end
        end
      end
    end

    desc 'Disables the site removing the symbolic link located in the enabled folder'
    task :disable => ['nginx:load_vars', 'nginx:validate_user_settings'] do
      on release_roles fetch(:nginx_roles) do
        if test "[ -f #{fetch(:enabled_application)} ]"
          within fetch(:sites_enabled) do
            arguments = :rm, '-f', fetch(:nginx_application_name)
            git_plugin.add_sudo_if_required arguments, 'nginx:sites:disable', :nginx_sites_enabled_dir
            execute *arguments, interaction_handler: PasswdInteractionHandler.new
          end
        end
      end
    end

    desc 'Removes the site by removing the configuration file from the available folder'
    task :remove => ['nginx:load_vars', 'nginx:validate_user_settings'] do
      on release_roles fetch(:nginx_roles) do
        if test "[ -f #{fetch(:available_application)} ]"
          within fetch(:sites_available) do
            arguments = :rm, fetch(:nginx_application_name)
            git_plugin.add_sudo_if_required arguments, 'nginx:sites:remove', :nginx_sites_available_dir
            execute *arguments, interaction_handler: PasswdInteractionHandler.new
          end
        end
      end
    end
  end

end
