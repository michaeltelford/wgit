require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new do |t|
    t.libs << 'test'
end

desc "Run tests"
task :default => :test

desc "Compile all project Ruby files."
task :compile do 
    paths = Dir["**/*.rb"]
    paths.each do |f|
        puts "\nCompiling #{f}..."
        puts `ruby -cw #{f}`
    end
end
