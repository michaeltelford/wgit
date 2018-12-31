require 'bundler/gem_tasks'
require 'rake/testtask'
require 'dotenv/tasks'

# To load .env vars into a task below:
#task mytask: :dotenv do
  # Things that require .env vars.
#end

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Print help information"
task default: :help

desc "Print help information"
task :help do
  system "bundle exec rake -D"
end

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
  if !Wgit::CONNECTION_DETAILS.empty?
    raise "Clear the CONNECTION_DETAILS before releasing the gem"
  else
    puts "Releasing gem version #{Wgit::VERSION}, using the #{args[:remote]} Git remote..."
    confirm "Have you correctly updated the version? (Y/n)"
    Rake::Task[:release].invoke args[:remote]
  end
end

def confirm(question)
  puts question
  input = STDIN.gets.strip
  exit unless input == "Y"
end
