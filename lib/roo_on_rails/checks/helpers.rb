require 'forwardable'
require 'singleton'
require 'thor'

module RooOnRails
  module Checks
    module Helpers
      class Receiver < Thor::Group
        include Singleton
        include Thor::Actions
      end

      def self.included(by)
        by.class_eval do
          extend Forwardable
          delegate %i(ask say set_color) => :'RooOnRails::Checks::Helpers::Receiver.instance'
        end
      end

      def bold(str)
        "\e[1;4m#{str}\e[22;24m"
      end
    end
  end
end
