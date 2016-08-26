require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task :default => :test

desc "Compile all project Ruby files with warnings."
task :compile do 
  paths = Dir["**/*.rb"]
  paths.each do |f|
    puts "\nCompiling #{f}..."
    puts `ruby -cw #{f}`
  end
end

desc "The SAFE RELEASE task which ensures DB details are blank."
task :RELEASE, [:remote] do |t, args|
  raise unless require_relative 'lib/wgit'
  if not Wgit::CONNECTION_DETAILS.empty?
    raise "Clear the CONNECTION_DETAILS before releasing the gem"
  else
    puts "Releasing gem version #{Wgit::VERSION}, using the #{args[:remote]} Git remote..."
    get_input "Do you wan't to continue? (Y/n)"
    Rake::Task[:release].invoke args[:remote]
  end
end

def get_input(question)
  puts question
  input = STDIN.gets.strip
  exit unless input == "Y"
end
