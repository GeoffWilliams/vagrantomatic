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


    def fix_folders()
      # can't use dig() might not be ruby 2.3
      if @config.has_key?("folders")
        @config["folders"] = Array(@config["folders"])

        # all paths must be fully qualified.  If we were asked to do a relative path, change
        # it to the current directory since that's probably what the user wanted.  Not right?
        # user supply correct path!
        @config["folders"] = @config["folders"].map { |folder|
          if ! folder.start_with? '/'
            folder = "#{Dir.pwd}/#{folder}"
          end
          folder
        }
      else
        @config["folders"] = []
      end
    end

    def initialize(vagrant_vm_dir, name, logger: nil, config:nil)
      @name           = name
      @vagrant_vm_dir = vagrant_vm_dir
      @logger         = Logger.new(logger).logger

      # if we encounter conditions such as missing or damaged files we may need
      # to force a save that would normally not be detected - eg if we load bad
      # json it gets fixed up to an empty hash which would them be compared to a
      # fresh read of the file (also results in empty hash) - so we must supply
      # another way to force the save here
      @force_save     = false

      # use supplied config if present, otherwise load from file
      if config
        @config = config

        # validate a user-supplied config now, at the point of insertion
        # by this point we have a config either from file or supplied by user it
        # must be valid for us to proceed!
        @logger.debug "validating config for #{name}"
        validate_config

        # user may have specified relative folders at time of creation - if so
        # we must now expand all paths in them and write them forever to config
        # file
        fix_folders
      else
        @config = configfile_hash

        # this passed-in config could still be bad - we will validate it before
        # use on either save() or get_vm()
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
        raise "get_vm called for instance but it is not in_sync! (call save() first?)"
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

    def execute_and_log(op)
      get_vm.execute(op) { |stdout, stderr|
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
      execute_and_log(:destroy)
      if Dir.exists? vm_instance_dir
        FileUtils::rm_rf(vm_instance_dir)
      end
    end

    def reload
      execute_and_log(:reload)
    end

    def reset
      execute_and_log(:destroy)
      execute_and_log(:up)
    end

    def run(command)
      # arrayify
      command = [command]
      command.unshift("-c")

      messages = []
      vm = get_vm
      # throw the command over the wall to derelect whatever the state of instance
      # for now just support ssh - for windows we could do `powershell -c` or
      # maybe even winRM
      executor = vm.execute(:ssh, command) { |stdout,stderr|
        line = "#{stdout}#{stderr}".strip
        @logger.debug line
        messages << line
      }
      @logger.info("command '#{command}' resulted in #{messages.size} lines")
      return executor.status, messages
    end

   end
 end
