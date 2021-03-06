# frozen_string_literal: true

require "colorize"

module Jira
  class ConsoleChecker
    def ok!
      print " OK".green << "\n"
      true
    end

    def abort!
      abort("jira:check exited with errors")
    end

    def error_and_abort!(e, indent = 1)
      print " FAIL".red << "\n"

      case e
      when Errno::ECONNREFUSED
        puts "ERROR".red + ": Could not connect to JIRA: #{ @checker.client.jira_config["url"] }"
        self.abort!

      when Jira::Checker::CheckerError
        puts(("  " * indent) + "- ERROR".red + ": #{e.message}")
        false

      when Jira::Checker::CheckerWarning
        puts(("  " * indent) + "- WARNING".yellow + ": #{e.message}")
        false

      when Jira::Checker::CheckerCompositeError
        puts(("  " * indent) + "- ERROR".red + ": #{e.message}")

        e.statuses.each { |hash, value|
          print(("  " * (indent + 1)) + "- #{hash}:")
          if value then self.ok! else puts(" ✕".red) end
        }
        false
      when Jira::Checker::CriticalCheckerError
        puts(("  " * indent) + "- ERROR".red + ": #{e.message}")
        self.abort!

      else
        puts "ERROR".red + ": Unexpected error occurred #{e.message}\n\n#{e.backtrace}"
        self.abort!
      end
    end

    def show_available_issue_types
      puts "AVAILABLE ISSUE TYPES: ".yellow
      if (@checker.client.Issuetype.all.each do |issue|
        puts "  - #{issue.name} [id: #{issue.id}]"
      end).empty?
        puts "  - NO ISSUE TYPES"
      end
    end

    def show_available_issue_states
      puts "AVAILABLE ISSUE STATES:".yellow
      @checker.client.Status.all.each do |state|
        puts "  - #{state.name} [id: #{state.id}]"
      end
    end

    def show_suggested_fields_mapping(mismatched_fields)
      fields = @checker.client.Field.all.select { |_f| _f.custom }

      puts "SUGGESTED MAPPINGS"
      mismatched_fields.each do |field_name|
        suggested_field_description = if (f = fields.find { |_f| _f.name == field_name.to_s })
          "#{f.id.yellow} (export MP_JIRA_FIELD_#{f.name.gsub(/[- ]/, "_")}='#{f.id}')"
        else
          "NO MATCH FOUND".red
        end

        puts "  - #{field_name}: #{suggested_field_description}"
      end

      puts "AVAILABLE CUSTOM FIELDS"
      fields.each do |field|
        puts "  - #{field.name} [id: #{field.id}]"
      end
    end

    def initialize(checker = Jira::Checker.new, env = ENV)
      @checker = checker
      @env = env
    end

    def check
      puts "Checking JIRA instance on #{@checker.client.jira_config["url"]}"
      print "Checking connection..."
      @checker.check_connection { |e| self.error_and_abort!(e) } && self.ok!

      print "Checking issue type presence..."

      self.show_available_issue_types unless @checker.check_issue_type { |e| self.error_and_abort!(e) } && self.ok!

      print "Checking project existence..."
      @checker.check_project { |e| self.error_and_abort!(e) } && self.ok!

      puts "Trying to manipulate issue..."
      print "  - create issue..."
      issue = @checker.client.Issue.build
      @checker.check_create_issue(issue) { |e| self.error_and_abort!(e, 2) } && self.ok!

      print "  - check workflow transitions..."
      @checker.check_workflow_transitions(issue) { |e| self.error_and_abort!(e, 2) } && self.ok!

      print "  - update issue..."
      @checker.check_update_issue(issue) { |e| self.error_and_abort!(e, 2) } && self.ok!

      print "  - add comment to issue..."
      @checker.check_add_comment(issue) { |e| self.error_and_abort!(e, 2) } && self.ok!

      print "  - delete issue..."
      @checker.check_delete_issue(issue) { |e| self.error_and_abort!(e, 2) } && self.ok!

      puts "Checking workflow..."
      show_issue_states = false
      @checker.client.jira_config["workflow"].each do |key, id|
        print "  - #{key} [id: #{id}]..."
        show_issue_states = true unless @checker.check_workflow(id) { |e| self.error_and_abort!(e, 2) } && self.ok!
      end

      print "Checking custom fields mappings..."
      @checker.check_custom_fields do |e|
        self.error_and_abort!(e)

        if e.instance_of?(Jira::Checker::CheckerCompositeError)
          self.show_suggested_fields_mapping(e.statuses.keys)
        end
      end && self.ok!

      # in case of mismatched issue states, print all available
      self.show_available_issue_states if show_issue_states

      print "Checking Project issue type presence..."

      self.show_available_issue_types unless
        @checker.check_project_issue_type { |e| self.error_and_abort!(e) } && self.ok!

      puts "Trying to manipulate project issue..."
      print "  - create issue..."
      issue = @checker.client.Issue.build
      @checker.check_create_project_issue(issue) { |e| self.error_and_abort!(e, 2) } && self.ok!

      print "  - update issue..."
      @checker.check_update_issue(issue) { |e| self.error_and_abort!(e, 2) } && self.ok!

      print "  - delete issue..."
      @checker.check_delete_issue(issue) { |e| self.error_and_abort!(e, 2) } && self.ok!

      self.check_webhook
    end

    def check_webhook
      if @env["MP_HOST"].nil?
        puts "WARNING: Webhook won't be check, set MP_HOST env variable if you want to check it".yellow
      else
        print "Checking webhooks for hostname \"#{@env["MP_HOST"]}\"..."
        @checker.check_webhook(@env["MP_HOST"]) { |e| self.error_and_abort!(e) } && self.ok!
      end
    end
  end
end
