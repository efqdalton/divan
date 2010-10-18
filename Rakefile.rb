require 'rubygems'
require 'init.rb'
require 'rake'

task :create_database do
  if ENV['database']
    Divan[ENV['database'].to_sym].create unless Divan[ENV['database'].to_sym].exists?
  else
    Divan.databases.each do |name, database|
      database.create unless database.exists?
    end
  end
end

task :create_views do
  if ENV['database']
    if ENV['design']
      Divan[ENV['design'].to_sym].create_views
    else
      Divan[ENV['database'].to_sym].create_views
    end
  else
    Divan.databases.each do |name, database|
      database.create_views
    end
  end
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "divan"
    gem.summary = "A Ruby CouchDB Client for insane people"
    gem.description = "This is a very simple CouchDB client that have few dependencies.\nThis client has a lot of interesting features, for example: easy access to CouchDB revisions.\n"
    gem.email = "dalthon@aluno.ita.br"
    gem.homepage = "http://github.com/efqdalton/divan"
    gem.authors = ["Dalton Pinto"]
    gem.files.exclude "config"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end