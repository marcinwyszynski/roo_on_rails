require 'pathname'
require 'securerandom'
require 'thor'

module ROR
  module BuildTestApp
    ROOT = Pathname.new('../../..').expand_path(__FILE__)
    BUNDLE_CACHE = ROOT.join('vendor/bundle')
    TEST_DIR = ROOT.join('tmp')
    SCAFFOLD_DIR = ROOT.join('vendor/base_test_app')
    SCAFFOLD_PATH = ROOT.join('vendor/base_test_app.tar')
    RAILS_NEW_OPTIONS = '--skip-test --skip-git --skip-spring --skip-bundle'

    class Helper < Thor::Group
      include Thor::Actions

      def shell_run(command)
        say_status 'running', command.gsub(Dir.pwd, '$PWD')
        %x{#{command}}
        raise 'command failed' unless $?.success?
      end

      def ensure_scaffold
        return self if SCAFFOLD_PATH.exist?
        SCAFFOLD_DIR.rmtree if SCAFFOLD_DIR.exist?
        TEST_DIR.mkpath

        shell_run "rails new #{SCAFFOLD_DIR} #{RAILS_NEW_OPTIONS}"

        append_to_file SCAFFOLD_DIR.join('Gemfile'), <<~EOF
          gem 'roo_on_rails', path: '../..'
        EOF

        create_file SCAFFOLD_DIR.join('.env'), <<~EOF
          NEW_RELIC_LICENSE_KEY=dead-0000-beef
        EOF

        Bundler.with_clean_env do
          shell_run "cd #{SCAFFOLD_DIR} && bundle install --path=#{BUNDLE_CACHE}"
        end

        shell_run "tar -C #{SCAFFOLD_DIR} -cf #{SCAFFOLD_PATH} ."
        SCAFFOLD_DIR.rmtree # make this conditional so results can be inspected
        self
      end

      def unpack_scaffold_at(path)
        path.mkpath
        shell_run "tar -C #{path} -xf #{SCAFFOLD_PATH}"
        self
      end

      def clear_test_app_at(path)
        path.rmtree if path.exist?
        self
      end

      def clear_scaffold
        say_status 'removing', 'scaffold app cache'
        SCAFFOLD_DIR.rmtree if SCAFFOLD_DIR.exist?
        SCAFFOLD_PATH.delete if SCAFFOLD_PATH.exist?
      end
    end


    def build_test_app
      let(:app_id) { '%s.%s' % [Time.now.strftime('%F.%H%M%S'), SecureRandom.hex(4)] }
      let(:app_path) { TEST_DIR.join(app_id) }
      let(:app_helper) { Helper.new }


      before do
        app_helper.ensure_scaffold.unpack_scaffold_at(app_path)
      end

      after do
        app_helper.clear_test_app_at(app_path)
      end
    end
  end
end


RSpec.configure do |config|
  config.extend ROR::BuildTestApp

  config.before(:suite) do
    ROR::BuildTestApp::Helper.new.clear_scaffold
  end
end