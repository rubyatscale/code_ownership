# typed: false
# frozen_string_literal: true

# Zeitwerk Compliance Smoke Test
#
# This test serves as a Zeitwerk compliance smoke test that validates the gem's
# file structure and naming conventions. It ensures that all files in the gem
# follow Zeitwerk's strict naming conventions by forcing the autoloader to
# eagerly load every constant and file in the gem.
#
# How it works:
# 1. Eager Loading: Forces Zeitwerk to immediately load all files and constants
#    in the gem, rather than loading them on-demand
# 2. Error Detection: If there are any naming convention violations, Zeitwerk
#    will raise an error during this process
# 3. Validation: The test passes only if no errors are raised
#
# What it catches:
# - Misnamed files (e.g., my_class.rb should define MyClass)
# - Incorrect directory structure relative to module nesting
# - Missing constants (files that exist but don't define expected constants)
# - Extra or orphaned files that don't follow naming patterns
# - Namespace violations (constants defined in wrong namespace for their location)

RSpec.describe 'zeitwerk autoloader' do
  it 'werks (successfully loads the gem)' do
    Zeitwerk::Loader.eager_load_namespace(CodeOwnership)
  rescue => error
    # Enhance the error message with more specific information
    enhanced_message = build_enhanced_error_message(error)
    raise enhanced_message
  end

  private

  def build_enhanced_error_message(error)
    message_parts = [
      'Zeitwerk eager loading failed with the following error:',
      '',
      "Original Error: #{error.class}: #{error.message}",
      '',
    ]

    # Add backtrace information to help identify the problematic file
    if error.backtrace
      gem_related_trace = error.backtrace.select do |line|
        line.include?('lib/') || line.include?('zeitwerk')
      end

      if gem_related_trace.any?
        message_parts << 'Relevant backtrace:'
        gem_related_trace.first(5).each do |line|
          message_parts << "  #{line}"
        end
        message_parts << ''
      end
    end

    # Try to identify which file might be causing the issue
    if /(?:wrong constant name|uninitialized constant|expected.*to define)/i.match?(error.message)
      message_parts << 'This error typically indicates:'
      message_parts << "- A file name doesn't match its constant name"
      message_parts << '- A constant is defined in the wrong namespace'
      message_parts << "- A file exists but doesn't define the expected constant"
      message_parts << ''
    end

    # Add helpful debugging information
    message_parts << 'To debug this issue:'
    message_parts << '1. Check that all files in lib/ follow zeitwerk naming conventions'
    message_parts << '2. Ensure each file defines a constant matching its file path'
    message_parts << '3. Verify modules/classes are in the correct namespace'

    message_parts.join("\n")
  end
end
