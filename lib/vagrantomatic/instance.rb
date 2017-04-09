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

      config  = false
      begin
        json    = File.read(configfile)
        config  = JSON.parse(json)
      rescue Errno::ENOENT
        @logger.error("#{configfile} does not exist")
      rescue JSON::ParserError
        @logger.error("JSON parser error in #{configfile}")
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
      if ! in_sync?
        File.open(configfile,"w") do |f|
          f.write(@config.to_json)
        end
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

    def run(command)
      # trhow the command over the wall to derelect whatever the state of instance
      command.shift("-c")
      get_vm.execute(:ssh, command)
    end

   end
 end
