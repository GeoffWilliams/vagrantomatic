# require "json"
# require "vagrantomatic/vagrantfile"
# require "vagrantomatic/logger"
#
require "derelict"
require "fileutils"
require "json"
module Vagrantomatic
  class Instance
    VAGRANTFILE         = "Vagrantfile"
    VAGRANTFILE_JSON    = "#{VAGRANTFILE}.json"
    # We ship our own Vagrantfile with all variables externalised inside this
    # gem and get it into position by symlinking B-)
    MASTER_VAGRANTFILE  = File.join(File.dirname(File.expand_path(__FILE__)), "../../res/#{VAGRANTFILE}")

    attr_accessor :config

    def initialize(vagrant_vm_dir, name, logger: nil, config:{})
      @name           = name
      @vagrant_vm_dir = vagrant_vm_dir
      @logger         = ::Vagrantomatic::Logger.new(logger).logger
      @config         = config
    end

    def vm_instance_dir
      File.join(@vagrant_vm_dir, @name)
    end

    def vagrantfile
      File.join(vm_instance_dir, VAGRANTFILE)
    end

    def configfile
      File.join(vm_instance_dir, VAGRANTFILE_JSON)
    end

    # return a hash of the configfile or false if error encountered
    def configfile_hash
      json    = File.read(configfile)
      config  = false
      begin
        config = JSON.parse(json)
      rescue JSON::ParserError
        @logger.error("JSON::ParserError encountered in #{configfile}, marking instance absent")
      end
      config
    end

    def configured?
      configured = false
      if Dir.exists? (vm_instance_dir) and File.exists?(configfile) and File.exists?(vagrantfile)
        json = File.read(configfile)
        configured = !! configfile_hash
      end
      configured
    end

    def save
      FileUtils.mkdir_p(vm_instance_dir)
      ensure_config
      ensure_vagrantfile
    end

    # Vagrant to be driven from a .json config file, all
    # the parameters are externalised here
    def ensure_config
      File.open(configfile,"w") do |f|
        f.write(@config.to_json)
      end
    end

    # The Vagrantfile itself is shipped as part of this
    # module and delivered via pluginsync, so we just need
    # to symlink it for each directory.  This gives us the
    # benefit being to update by dropping a new module too
    def ensure_vagrantfile
      FileUtils.ln_sf(MASTER_VAGRANTFILE, vagrantfile)
    end


    def get_vm
      # Create an instance (represents a Vagrant **installation**)
      instance = Derelict.instance(Vagrantomatic::Vagrantomatic::VAGRANT_DIR)
      result = instance.execute('--version') # Derelict::Executer object (vagrant --version)
      if result.success?
        # vagrant present and working, connect to our vm INSTANCE
        vm = instance.connect(@vm_instance_dir)
      else
        raise "Error connecting to vagrant! (vagrant --version failed)"
      end

      vm
    end

    def in_sync?
      configured  = false
      have_config = configfile_hash

      if have_config == @config
        configured = true
      end

      configured
    end

    def start
      get_vm.execute(:up).success?
    end

    def stop
      get_vm.execute(:suspend).success?
    end

    def purge
      get_vm.execute(:destroy)
      FileUtils::rm_rf(@vm_instance_dir)
    end

    def reload
      set_vm.execute(:reload)
    end

   end
 end
#     DEFAULT_VAGRANT_DIR     = "/usr"
#     DEFAULT_VAGRANT_VM_DIR  = "/var/lib/vagrantomatic"
#
#     def initialize(vagrant_vm_dir: nil, logger: nil)
#       @vagrant_vm_dir = vagrant_vm_dir || DEFAULT_VAGRANT_VM_DIR
#       @logger = Vagrantomatic::Logger.new(logger).logger
#     end
#
#     # Return a has representing the named instance.  This is suitable for Puppet
#     # type and provider, or you can use the returned info for whatever you like
#     def parse_instance(instance_name)
#       instance_dir = File.join(@vagrant_vm_dir, instance_name)
#       config_file = File.join(instance_dir, Vagrantomatic::Vagrantfile::VAGRANTFILE_JSON)
#       config = {}
#       if File.exists?(config_file)
#
#         # json validity test
#         json = File.read(config_file)
#         begin
#           config = JSON.parse(json)
#           config["ensure"] = :present
#         rescue JSON::ParserError
#           @logger.error("JSON::ParserError encountered in #{config_file}, marking instance absent")
#           config["ensure"] = :absent
#         end
#       else
#         # VM missing or damaged
#         config["ensure"] = :absent
#
#       end
#       config["name"] = instance_name
#       config
#     end
#
#     # Return a has of instances
#     def instances()
#       instance_wildcard = File.join(@vagrant_vm_dir, "*", Vagrantomatic::Vagrantfile::VAGRANTFILE)
#       instances = {}
#       Dir.glob(instance_wildcard).each { |f|
#         elements = f.split(File::SEPARATOR)
#         # /var/lib/vagrantomatic/mycoolvm/Vagrantfile
#         # -----------------------^^^^^^^^------------
#         name = elements[elements.size - 2]
#
#         instances[name] = parse_instance(name)
#       }
#
#       instances
#     end
#
#     def configured?
#       configured = false
#       if Dir.exists? (vm_instance_dir) and File.exists?(configfile) and File.exists?(vagrantfile)
#
#         json = File.read(configfile)
#         have_config = JSON.parse(json)
#
#         if have_config == @config
#           configured = true
#         end
#       end
#       configured
#     end
#
#
#
#   end
#
# end
