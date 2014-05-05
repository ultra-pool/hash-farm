require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module HashFarm
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.autoload_paths += %W(#{config.root}/lib)

    config.assets.paths << Rails.root.join('app', 'assets', 'fonts')

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :en
    config.i18n.enforce_available_locales = false

    config.serialized_master_key = {
      public: 'xpub661MyMwAqRbcG2V5zGfVX28LzHCBm7BHhEeMun3WjJUJQhmT6SnhpF2m2BXh7bwnbQ3x3oRGW2hjxzkBcCu8oDjNod4cUJT9j5pHoMVFGsE',
      private: nil
    }

    if File.exists?("#{Rails.root}/private_master_key").present?
      config.serialized_master_key[:private] = File.read("#{Rails.root}/private_master_key").chomp
    end

  end

  def self.config
    Application.config
  end


end
