divan_path = File.expand_path('../lib', __FILE__)
$:.unshift(divan_path) if File.directory?(divan_path) && !$:.include?(divan_path)

require 'restclient'
require 'json'
require 'divan.rb'

Divan.load_database_configuration 'config/divan_config.yml'

# Lines below are used for debug purposes only
class POC < Divan::Models::ProofOfConcept
  view_by :mod
  view_by :value
end
