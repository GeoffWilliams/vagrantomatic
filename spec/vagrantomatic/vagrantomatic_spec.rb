require "spec_helper"
require "vagrantomatic/vagrantomatic"

RSpec.describe Vagrantomatic::Vagrantomatic do
  it "single named instance parsed correctly" do
    vom = Vagrantomatic::Vagrantomatic.new(vagrant_vm_dir:'spec/fixtures/vagrant')
    instance = vom.instance_metadata("inst_a")
    expect(instance.has_key?("ensure")).to be true
    expect(instance["ensure"]).to eq :present
  end

  it "detects instances correctly" do
    vom = Vagrantomatic::Vagrantomatic.new(vagrant_vm_dir:'spec/fixtures/vagrant')
    instances = vom.instances_metadata

    expect(instances.size).to be 3

    # good vm
    expect(instances.has_key?("inst_a")).to be true
    expect(instances["inst_a"].has_key?("ensure")).to be true
    expect(instances["inst_a"]["ensure"]).to eq :present

    # missing a box key in vagrantfile.json
    expect(instances.has_key?("inst_b")).to be true
    expect(instances["inst_b"].has_key?("ensure")).to be true
    expect(instances["inst_b"]["ensure"]).to eq :absent

    # absent because no Vagrantfile.json
    expect(instances.has_key?("inst_c")).to be true
    expect(instances["inst_c"].has_key?("ensure")).to be true
    expect(instances["inst_c"]["ensure"]).to eq :absent
  end

  it "detects deformed instances correctly" do
    vom = Vagrantomatic::Vagrantomatic.new(vagrant_vm_dir: 'spec/fixtures/bad_vagrant')
    instances = vom.instances_metadata

    expect(instances.size).to be 1

    expect(instances.has_key?("broken")).to be true
    expect(instances["broken"].has_key?("ensure")).to be true
    expect(instances["broken"]["ensure"]).to eq :absent
  end

  it "creates a valid Vagrantomatic::Instance" do
    vom = Vagrantomatic::Vagrantomatic.new(vagrant_vm_dir:'spec/fixtures/vagrant')
    instance = vom.instance("inst_a")
    expect(instance.class).to be Vagrantomatic::Instance
  end
end
