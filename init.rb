require "#{File.dirname(__FILE__)}/lib/divan.rb"

#Lines below are used for debug purposes only
Divan.load_database_configuration 'config/divan_config.yml'

class ProofOfConcept < Divan::Models::ProofOfConcept
end

class POC < Divan::Models::ProofOfConcept
  view_by :mod
  view_by :value
end
