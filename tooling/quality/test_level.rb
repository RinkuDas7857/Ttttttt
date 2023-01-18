# frozen_string_literal: true

module Quality
  class TestLevel
    UnknownTestLevelError = Class.new(StandardError)

    TEST_LEVEL_FOLDERS = {
      migration: %w[
        migrations
      ],
      background_migration: %w[
        lib/gitlab/background_migration
        lib/ee/gitlab/background_migration
      ],
      frontend_fixture: %w[
        frontend/fixtures
      ],
      unit: %w[
        bin
        channels
        config
        contracts
        db
        dependencies
        elastic
        elastic_integration
        experiments
        factories
        finders
        frontend
        graphql
        haml_lint
        helpers
        initializers
        lib
        metrics_server
        models
        policies
        presenters
        rack_servers
        replicators
        routing
        rubocop
        scripts
        serializers
        services
        sidekiq
        sidekiq_cluster
        spam
        support_specs
        tasks
        uploaders
        validators
        views
        workers
        tooling
        components
      ],
      integration: %w[
        commands
        controllers
        mailers
        requests
      ],
      system: ['features']
    }.freeze

    attr_reader :prefixes

    def initialize(prefixes = nil)
      @prefixes = Array(prefixes)
      @patterns = {}
      @regexps = {}
    end

    def pattern(level)
      @patterns[level] ||= "#{prefixes_for_pattern}spec/#{folders_pattern(level)}{,/**/}*#{suffix(level)}".freeze # rubocop:disable Style/RedundantFreeze
    end

    def regexp(level)
      @regexps[level] ||= Regexp.new("#{prefixes_for_regex}spec/#{folders_regex(level)}").freeze
    end

    def level_for(file_path)
      case file_path
      # Detect background migration first since some are under
      #     spec/lib/gitlab/background_migration
      # and tests under spec/lib are unit by default
      when regexp(:background_migration)
        :background_migration
      when regexp(:migration)
        :migration
      # Detect frontend fixture before matching other unit tests
      when regexp(:frontend_fixture)
        :frontend_fixture
      when regexp(:unit)
        :unit
      when regexp(:integration)
        :integration
      when regexp(:system)
        :system
      else
        raise UnknownTestLevelError, "Test level for #{file_path} couldn't be set. Please rename the file properly or change the test level detection regexes in #{__FILE__}."
      end
    end

    private

    def prefixes_for_pattern
      return '' if prefixes.empty?

      "{#{prefixes.join(',')}}"
    end

    def prefixes_for_regex
      return '' if prefixes.empty?

      regex_prefix = prefixes.map { |prefix| Regexp.escape(prefix) }.join('|')

      "(#{regex_prefix})"
    end

    def suffix(level)
      case level
      when :frontend_fixture
        ".rb"
      else
        "_spec.rb"
      end
    end

    def folders_pattern(level)
      case level
      when :all
        '**'
      else
        "{#{TEST_LEVEL_FOLDERS.fetch(level).join(',')}}"
      end
    end

    def folders_regex(level)
      case level
      when :all
        ''
      else
        "(#{TEST_LEVEL_FOLDERS.fetch(level).join('|')})/"
      end
    end
  end
end
