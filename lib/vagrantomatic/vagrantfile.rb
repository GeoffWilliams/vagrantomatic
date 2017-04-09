module Vagrantomatic
  class Vagrantfile

    VAGRANTFILE       = "Vagrantfile"
    VAGRANTFILE_RES   = File.join(File.dirname(File.expand_path(__FILE__)), "../../res/#{VAGRANTFILE}")
    VAGRANTFILE_JSON  = "#{VAGRANTFILE}.json"

    def initialize(name:, vm_dir:DEFAULT_VAGRANT_VM_DIR)

    end

    def ensure(
        name,
        box           = false,
        provision     = false,
        synced_folder = false,
        memory        = false,
        cpu           = false,
        user          = false,
        ip            = false,
        act           = true)

      @user   = user
      @config = {
        "name"           => name,
        "box"            => box,
        "provision"      => provision,
        "synced_folder"  => synced_folder,
        "memory"         => memory,
        "cpu"            => cpu,
        "ip"             => ip,
      }


      if act
        if ! Dir.exists?(vm_instance_dir)
          FileUtils.mkdir_p(vm_instance_dir)
        end

        ensure_config
        ensure_vagrantfile
      end
    end


    def configured?
      configured = false
      if Dir.exists? (vm_instance_dir) and File.exists?(configfile) and File.exists?(vagrantfile)

        json = File.read(configfile)
        have_config = JSON.parse(json)

        if have_config == @config
          configured = true
        end
      end
      configured
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
      source_file = File.join(Puppet[:factpath].split(':')[0], 'Vagrantfile')
      FileUtils.ln_sf(source_file, vagrantfile)
    end

  end
end
