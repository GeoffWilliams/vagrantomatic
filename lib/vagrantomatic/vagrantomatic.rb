require "vagrantomatic/version"
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
      config = {}
      # annotate the raw config hash with data for puppet (and humans...)
      if instance.configured?
        config = instance.configfile_hash
        config["ensure"] = :present
      else
        # VM missing or damaged
        config["ensure"] = :absent
      end
      config["name"] = name

      config
    end

    # Return a has of instances
    def instances_metadata()
      instance_wildcard = File.join(@vagrant_vm_dir, "*", ::Vagrantomatic::Instance::VAGRANTFILE)
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
      ::Vagrantomatic::Instance.new(@vagrant_vm_dir, name, logger: @logger)
    end

  end
end
