require "bundler/setup"
require "minitest/reporters"
require "minitest/focus"
require "minitest/autorun"

ENV["RACK_ENV"] = "test"

require "simplecov"
require "simplecov-lcov"
SimpleCov.coverage_dir(ENV["COVERAGE_REPORTS"])
SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatters = [
  SimpleCov::Formatter::LcovFormatter,
  SimpleCov::Formatter::HTMLFormatter
]
SimpleCov.start do
  add_filter(%r{^/spec/})
end

if ENV["CI"] == "true"
  Minitest::Reporters.use!(
    [Minitest::Reporters::DefaultReporter.new,
     Minitest::Reporters::JUnitReporter.new(ENV["CI_REPORTS"] || "coverage/ci")]
  )
else
  Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new)
end

Minitest::Test.make_my_diffs_pretty!
