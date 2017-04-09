require "vagrantomatic/version"
require "vagrantomatic/vagrantfile"
require "vagrantomatic/logger"
require "vagrantomatic/instance"
require "json"

module Vagrantomatic
  class Vagrantomatic
    DEFAULT_VAGRANT_DIR     = "/usr"
    DEFAULT_VAGRANT_VM_DIR  = "/var/lib/vagrantomatic"

    def initialize(vagrant_vm_dir: nil, logger: nil)
      @vagrant_vm_dir = vagrant_vm_dir || DEFAULT_VAGRANT_VM_DIR
      @logger = ::Vagrantomatic::Logger.new(logger).logger
    end

    # Return a has representing the named instance.  This is suitable for Puppet
    # type and provider, or you can use the returned info for whatever you like
    def instance_metadata(name)
      instance = ::Vagrantomatic::Instance.new(@vagrant_vm_dir, name)
      # instance_dir = File.join(@vagrant_vm_dir, instance_name)
      # config_file = File.join(instance_dir, ::Vagrantomatic::Vagrantfile::VAGRANTFILE_JSON)
      config = {}
      configfile = instance.configfile
      if File.exists?(instance.configfile)

        # json validity test
        json = File.read(configfile)
        begin
          config = JSON.parse(json)
          config["ensure"] = :present
        rescue JSON::ParserError
          @logger.error("JSON::ParserError encountered in #{instance.configfile}, marking instance absent")
          config["ensure"] = :absent
        end
      else
        # VM missing or damaged
        config["ensure"] = :absent

      end
      config["name"] = name
      config
    end

    # Return a has of instances
    def instances_metadata()
      instance_wildcard = File.join(@vagrant_vm_dir, "*", ::Vagrantomatic::Vagrantfile::VAGRANTFILE)
      instances = {}
      Dir.glob(instance_wildcard).each { |f|
        elements = f.split(File::SEPARATOR)
        # /var/lib/vagrantomatic/mycoolvm/Vagrantfile
        # -----------------------^^^^^^^^------------
        name = elements[elements.size - 2]

        instances[name] = instance_metadata(name)
      }

      instances
    end

    def instance(name)
      ::Vagrantomatic::Instance.new(@vagrant_vm_dir, name)
    end

  end
end
