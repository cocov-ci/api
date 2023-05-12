# frozen_string_literal: true

module Cocov
  module Status
    class SidekiqProbes
      def initialize(address:, port:)
        require "webrick"

        @address = address
        @port = port
        @running = false
      end

      def stop
        @server.stop
      end

      def start
        @thread = Thread.new { run }
        Timeout.timeout(5) { sleep(0.01) until @running }
      end

      private

      def run
        @server = ::WEBrick::HTTPServer.new(
          Port: @port,
          BindAddress: @address,
          StartCallback: -> { @running = true },
          AccessLog: [],
          Logger: WEBrick::Log.new("/dev/null")
        )
        @server.mount("/", Rack::Handler::WEBrick, app)
        @server.start
      end

      def app
        Rack::Builder.app do
          use Rack::Deflater
          run lambda { |env|
            case env["PATH_INFO"]
            when "/system/probes/readiness", "/system/probes/liveness"
              [
                200,
                { "Content-Type" => "application/json; charset=utf-8" },
                [{ ok: true }.to_json]
              ]
            when "/system/ping"
              [204, {}, [""]]
            else
              [404, {}, [""]]
            end
          }
        end
      end
    end
  end
end
