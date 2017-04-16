require "spec_helper"
require "fileutils"
require "vagrantomatic/vagrantomatic"

RSpec.describe Vagrantomatic::Instance do
  CONFIG_GOOD         = {"box"=>"foo"}
  CONFIG_MISSING_BOX  = {}
  CONFIG_SHARED_REL   = {"box"=>"foo", "folders"=>['foo:/bar']}
  CONFIG_SHARED_ABS   = {"box"=>"foo", "folders"=>['/foo:/bar']}

  # dont bother testing the string munging functions unless a bug report comes
  # too simple - waste of time

  it "passes loading good vm from file" do
    instance = Vagrantomatic::Instance.new('spec/fixtures/vagrant', 'inst_a')
    instance.configured?

    # pass
  end

  it "passes creating new vm with good parameters" do
    instance = Vagrantomatic::Instance.new('/tmp/foo', 'foo', config: CONFIG_GOOD)

    # pass
  end


  it "errors errors on missing box for new vm" do
    expect{Vagrantomatic::Instance.new('/tmp/foo', 'foo', config: CONFIG_MISSING_BOX)}.to raise_error /must specify box/
  end


  it "squashes invalid json without causing a fuss and marks file as out of sync to be overwritten" do
    vi = Vagrantomatic::Instance.new('spec/fixtures/bad_vagrant', 'broken')
    expect(vi.in_sync?).to be false

    # pass
  end


  it "reports incomplete vm correctly (missing boxs) on save" do
    vi = Vagrantomatic::Instance.new('spec/fixtures/vagrant', 'inst_b')
    expect{vi.save()}.to raise_error /must specify box/i
  end

  it "reports incomplete vm correctly (missing boxs) on get_vm" do
    vi = Vagrantomatic::Instance.new('spec/fixtures/vagrant', 'inst_b')
    expect{vi.get_vm()}.to raise_error /must specify box/i
  end


  it "configured? reports nonexistant vm correctly" do
    # supply enough info to create an instace
    instance = Vagrantomatic::Instance.new('spec/fixtures/nothere', 'missing', config: CONFIG_GOOD)

    # the instance was not saved so configured? should be false
    expect(instance.configured?).to be false
  end

  it "configured? reports good vm configured? as true" do
    # supply enough info to create an instace
    instance = Vagrantomatic::Instance.new('spec/fixtures/vagrant', 'inst_a')

    # the instance was not saved so configured? should be false
    expect(instance.configured?).to be true
  end

  it "saves and validates a new VM" do
    # create a new vm in a temp dir
    tmpdir = Dir.mktmpdir
    instance = Vagrantomatic::Instance.new(tmpdir, 'newvm', config:CONFIG_GOOD)

    # test nothing exists yet
    expect(instance.configured?).to be false

    # save and check we have a valid instance now
    instance.save
    expect(instance.configured?).to be true

    # cleanup
    FileUtils.rm_rf(tmpdir)
  end

  it "detects when Vagrantfile.json needs saving" do
    instance = Vagrantomatic::Instance.new('spec/fixtures/vagrant', 'inst_a')
    instance.config=({'cpus' => 6})
    expect(instance.in_sync?).to be false
  end

  it "detects when Vagrantfile.json up to date" do
    instance = Vagrantomatic::Instance.new('spec/fixtures/vagrant', 'inst_a')
    expect(instance.in_sync?).to be true
  end

  it "expands relative shared folder paths correctly" do
    instance = Vagrantomatic::Instance.new(
      'spec/fixtures/vagrant', 'inst_a', config: CONFIG_SHARED_REL)
    expect(instance.config["folders"][0].start_with?(Dir.pwd)).to be true
  end


  it "does not expands absoluted shared folder paths" do
    instance = Vagrantomatic::Instance.new(
      'spec/fixtures/vagrant', 'inst_a', config: CONFIG_SHARED_ABS)
    expect(instance.config["folders"][0].start_with?(Dir.pwd)).to be false
  end

end
