require 'init.rb'

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
      Divan[ENV['database'].to_sym].create_views
    else
      Divan[ENV['database'].to_sym].create_views
    end
  else
    Divan.databases.each do |name, database|
      database.create_views
    end
  end
end