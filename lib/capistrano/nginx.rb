require "capistrano/plugin"
module Capistrano
  class Nginx < Capistrano::Plugin

    def set_defaults
      set :nginx_sudo_paths,          -> { [:nginx_log_path, :nginx_sites_enabled_dir, :nginx_sites_available_dir] }
      set :nginx_sudo_tasks,          -> { ['nginx:start', 'nginx:stop', 'nginx:restart', 'nginx:reload', 'nginx:configtest', 'nginx:site:add', 'nginx:site:disable', 'nginx:site:enable', 'nginx:site:remove' ] }
      set :nginx_log_path,            -> { "#{shared_path}/log" }
      set :nginx_service_path,        -> { 'service nginx' }
      set :nginx_static_dir,          -> { "public" }
      set :nginx_application_name,    -> { fetch(:application) }
      set :nginx_sites_enabled_dir,   -> { "/etc/nginx/sites-enabled" }
      set :nginx_sites_available_dir, -> { "/etc/nginx/sites-available" }
      set :nginx_roles,               -> { :sudo }
      set :nginx_template,            -> { :default }
      set :nginx_use_ssl,             -> { false }
      set :nginx_ssl_certificate,          -> { "#{fetch(:application)}.crt" }
      set :nginx_ssl_certificate_path,     -> { '/etc/ssl/certs' }
      set :nginx_ssl_certificate_key,      -> { "#{fetch(:application)}.key" }
      set :nginx_ssl_certificate_key_path, -> { '/etc/ssl/private' }
      set :app_server,                     -> { true }
    end

    def define_tasks
      eval_rakefile File.expand_path('../tasks/nginx.rake', __FILE__)
    end

    # prepend :sudo to list if arguments if :key is in :nginx_use_sudo_for list
    def add_sudo_if_required argument_list, *keys
      keys.each do | key |
        if nginx_use_sudo? key
          argument_list.unshift(:sudo)
          break
        end
      end
    end

    def nginx_use_sudo? key
      (fetch(:nginx_sudo_tasks).include?(key) || fetch(:nginx_sudo_paths).include?(key))
    end

    class PasswdInteractionHandler
      def on_data(command, stream_name, data, channel)
        if data.include?("[sudo]")
          ask(:password, 'sudo', echo: false)
          channel.send_data("#{fetch(:password)}\n")
        elsif data.include?("UNIX password")
          ask(:password, 'UNIX', echo: false)
          channel.send_data("#{fetch(:password)}\n")
        else
        end
      end
    end

  end
end
