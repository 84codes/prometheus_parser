require "bundler/setup"
require "rake/testtask"
require "dotenv/load"

Rake::TestTask.new(:test) do |t|
  t.libs << "spec"
  t.libs << "lib"
  t.test_files = FileList["spec/**/*_spec.rb"]
end

task default: :test
