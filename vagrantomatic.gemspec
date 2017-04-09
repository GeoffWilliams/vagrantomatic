# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vagrantomatic/version'

Gem::Specification.new do |spec|
  spec.name          = "vagrantomatic"
  spec.version       = Vagrantomatic::VERSION
  spec.authors       = ["Geoff Williams"]
  spec.email         = ["geoff@geoffwilliams.me.uk"]

  spec.summary       = %q{automatically create and manage Vagrantfile with ruby}
  spec.homepage      = "https://github.com/GeoffWilliams/vagrantomatic"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
