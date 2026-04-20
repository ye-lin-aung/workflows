require "bundler/setup"

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"
load "rails/tasks/statistics.rake"
require "bundler/gem_tasks"

require "rake/testtask"
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
  # Always boot Minitest so `rake test` prints a summary ("0 tests, 0
  # assertions, ...") even when no test files match the pattern yet.
  t.ruby_opts = ["-rminitest/autorun"]
  t.verbose = false
end

task default: :test
