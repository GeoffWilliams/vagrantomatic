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


    CMD_DEFAULT = "sudo -i"
    CMD_WINDOWS = "cmd /c"

    def config
      @config
    end

    def windows
      @windows
    end

    # ruby convention is to use `config=` but this doesn't work properly inside
    # a constructor, it declarates a local variable `config`.  Calling from
    # outside the constructor works fine...
    def set_config(config)
      @config = config
      validate_config
    end

    def validate_config(fatal = true)
      valid = true
      if ! @config.has_key?("box")
        valid = false
        if fatal
          raise "Node #{@name} must specify box"
        end
      end

      valid
    end

    # Add a new folder to @config in the correct place.  Folders must be
    # specified as colon delimited strings: `HOST_PATH:VM_PATH`, eg
    # `/home/geoff:/stuff` would mount `/home/geoff` from the main computer and
    # would mount it inside the VM at /stuff.  Vagrant expects the `HOST_PATH`
    # to be an absolute path, however, you may specify a relative path here and
    # vagrantomatic will attempt to extract a fully qualified path by prepending
    # the present working directory.  If this is incorrect its up to the
    # programmer to fix this by passing in a fully qualified path in the first
    # place
    def add_shared_folder(folders)
      folders=Array(folders)
      # can't use dig() might not be ruby 2.3
      if ! @config.has_key?("folders")
        @config["folders"] = []
      end


      # all paths must be fully qualified.  If we were asked to do a relative path, change
      # it to the current directory since that's probably what the user wanted.  Not right?
      # user supply correct path!
      folders.each { |folder|
        if ! folder.start_with? '/'
          folder = "#{Dir.pwd}/#{folder}"
        end

        @config["folders"] << folder
      }
    end

    def initialize(vagrant_vm_dir, name, logger:nil, config:nil)
      @name           = name
      @vagrant_vm_dir = vagrant_vm_dir
      @logger         = Logger.new(logger).logger

      # (attempt) to auto-detect windows based on the VM name containing 'win'
      # allow users to override this with config[windows]=true
      @windows = ((/win/i === @name)  or (@config.has_key?('windows') and config['windows'] == true))


      # if we encounter conditions such as missing or damaged files we may need
      # to force a save that would normally not be detected - eg if we load bad
      # json it gets fixed up to an empty hash which would them be compared to a
      # fresh read of the file (also results in empty hash) - so we must supply
      # another way to force the save here
      @force_save     = false

      # use supplied config if present, otherwise load from file
      if config
        # validate a user-supplied config now, at the point of insertion
        # by this point we have a config either from file or supplied by user it
        # must be valid for us to proceed!
        set_config(config)
      else

        # this passed-in config could still be bad - we will validate it before
        # use on either save() or get_vm().  We DONT validate it right away
        # because this would cause the constructor to explode when we are trying
        # to introspec intances - we would never be able to fix anything
        # automatically
        @config = configfile_hash
      end

      @logger.debug "initialized vagrantomatic instance for #{name}"
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

    # return a hash of the configfile or empty hash if error encountered
    def configfile_hash

      config  = {}
      begin
        json    = File.read(configfile)
        config  = JSON.parse(json)
      rescue Errno::ENOENT
        # depending on whether the instance has been saved or not, we may not
        # yet have a configfile - allow to proceed
        @logger.debug "#{configfile} does not exist"
        @force_save = true
      rescue JSON::ParserError
        # swallow parse errors so that we can destroy and recreate automatically
        @logger.debug "JSON parse error in #{configfile}"
        @force_save = true
      end
      config
    end

    def configured?
      configured = true

      if ! Dir.exists? (vm_instance_dir)
        @logger.debug "Vagrant instance directory #{vm_instance_dir} does not exist"
        configured = false
      end

      if ! File.exists?(vagrantfile)
        @logger.debug "#{VAGRANTFILE} not found at #{vagrantfile}"
        configured = false
      end

      if ! File.exists?(configfile)
        @logger.debug "#{VAGRANTFILE_JSON} not found at #{configfile}"
        configured = false
      end

      # check config hash is valid without causing a fatal error if its damaged
      if ! validate_config(false)
        configured = false
      end

      configured
    end

    def save
      @logger.debug("validating settings for save...")
      validate_config
      @logger.debug("saving vm settings...")
      FileUtils.mkdir_p(vm_instance_dir)
      ensure_config
      ensure_vagrantfile

      @force_save = false
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
      if ! in_sync?
        raise "get_vm called for instance #{@name} but it is not in_sync! (call save() first?)"
      end

      validate_config

      vagrant_installation = Derelict.instance(Vagrantomatic::DEFAULT_VAGRANT_DIR)
      result = vagrant_installation.execute('--version') # Derelict::Executer object (vagrant --version)
      if result.success?
        # vagrant present and working, connect to our vm INSTANCE
        vm = vagrant_installation.connect(vm_instance_dir)
      else
        raise "Error connecting to vagrant! (vagrant --version failed)"
      end

      vm
    end

    def execute_and_log(op, *args)
      get_vm.execute(op, args) { |stdout, stderr|
        # only one of these will ever be set at a time, other one is nil
        @logger.debug "#{stdout}#{stderr}".strip
      }.success?
    end

    def in_sync?
      configured  = false
      have_config = configfile_hash
      if (! @force_save) and (have_config == @config )
        configured = true
      end

      configured
    end

    def start
      execute_and_log(:up)
    end

    def stop
      execute_and_log(:suspend)
    end

    def purge
      execute_and_log(:destroy, '-f')
      if Dir.exists? vm_instance_dir
        FileUtils::rm_rf(vm_instance_dir)
      end
    end

    def reload
      execute_and_log(:reload)
    end

    def reset
      execute_and_log(:destroy, '-f')
      execute_and_log(:up)
    end

    def run(command)
      # arrayify and wrap with correct command for windows vs linux
      command = ["#{@windows ? CMD_WINDOWS : CMD_DEFAULT} #{command}"]
      command.unshift("-c")

      messages = []
      vm = get_vm
      # throw the command over the wall to derelect whatever the state of instance
      # using the appropriate subcommand
      runner = @windows ? :winrm : :ssh
      executor = vm.execute(runner, command) { |stdout,stderr|
        line = "#{stdout}#{stderr}".strip
        @logger.debug line
        messages << line
      }
      @logger.info("command '#{command}' resulted in #{messages.size} lines (exit status: #{executor.status})")
      return executor.status, messages
    end

  end
end
