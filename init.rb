divan_path = File.expand_path('../lib', __FILE__)
$:.unshift(divan_path) if File.directory?(divan_path) && !$:.include?(divan_path)

require 'restclient'
require 'json'
require 'divan.rb'

# Lines below are used for debug purposes only
# Divan.load_database_configuration 'config/divan_config.yml'
# 
# class POC < Divan::Models::ProofOfConcept
#   view_by :mod
#   view_by :value
# end
