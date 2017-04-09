require "spec_helper"
require "fileutils"
require "vagrantomatic/vagrantomatic"

RSpec.describe Vagrantomatic::Instance do

  # dont bother testing the string munging functions unless a bug report comes
  # too simple - waste of time

  it "configured? reports good vm correctly" do
    instance = Vagrantomatic::Instance.new('spec/fixtures/vagrant', 'inst_a')
    expect(instance.configured?).to be true
  end

  it "configured? reports bad vm correctly" do
    instance = Vagrantomatic::Instance.new('spec/fixtures/bad_vagrant', 'broken')
    expect(instance.configured?).to be false
  end

  it "configured reports nonexistant vm correctly" do
    instance = Vagrantomatic::Instance.new('spec/fixtures/nothere', 'missing')
    expect(instance.configured?).to be false
  end

  it "saves and validates a new VM" do
    # create a new vm in a temp dir
    tmpdir = Dir.mktmpdir
    puts tmpdir
    instance = Vagrantomatic::Instance.new(tmpdir, 'newvm')

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

end
