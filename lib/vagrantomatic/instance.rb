# require "json"
# require "vagrantomatic/vagrantfile"
# require "vagrantomatic/logger"
#
require "derelict"
require "fileutils"
module Vagrantomatic
  class Instance
    VAGRANTFILE       = "Vagrantfile"
    VAGRANTFILE_JSON  = "#{VAGRANTFILE}.json"

    def initialize(name:, vagrant_vm_dir:)
      @name            = name
      @vagrant_vm_dir  = vagrant_vm_dir
    end

    def vm_instance_dir
      File.join(@vagrant_vm_dir, @config["name"])
    end

    def vagrantfile
      File.join(vm_instance_dir, VAGRANTFILE)
    end

    def configfile
      File.join(vm_instance_dir, VAGRANTFILE_JSON)
    end

    def configured?
      configured = false
      if Dir.exists? (@vm_instance_dir) and File.exists?(configfile) and File.exists?(vagrantfile)

        json        = File.read(configfile)
        have_config = JSON.parse(json)

        if have_config == @config
          configured = true
        end
      end
      configured
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
