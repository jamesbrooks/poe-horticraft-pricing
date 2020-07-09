require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

loader = Zeitwerk::Loader.new
loader.push_dir("lib")
loader.setup

HorticraftingPricing.new.run
