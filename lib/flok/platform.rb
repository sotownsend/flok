#Contains helpers for getting information about the flok folders (like platforms available)

module Flok
  module Platform
    def self.list
      Dir.chdir './app/drivers' do
        #Get a list of directories, each directory is technically a platform
        dirs = Dir["*"].select{|e| File.directory?(e)}

        return dirs
      end
    end

    #Get a list of modules for a particular environment for a platform
    def self.mods platform, environment
      #Create array that looks like a javascript array with single quotes
      mods = self.config_yml(platform, environment)['mods']
    end

    #Get all config.yml information for a platform
    def self.config_yml platform, environment
      #If $FLOK_CONFIG is specified, then we will use that instead of the default config.yml,
      #the config must be specified as an absolute path
      if ENV['FLOK_CONFIG']
        driver_config = YAML.load_file(ENV['FLOK_CONFIG'])
      else
        driver_config = YAML.load_file("./app/drivers/#{platform}/config.yml")
      end

      raise "No config.yml found in your 'platform: #{platform}' driver" unless driver_config
      return driver_config[environment]
    end
  end

  #Alias
  def self.platforms
    return Platform.list
  end
end
