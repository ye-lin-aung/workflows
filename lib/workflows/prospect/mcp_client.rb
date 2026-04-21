require "json"
require "open3"

module Workflows
  module Prospect
    class McpClient
      class ProtocolError < StandardError; end

      PROTOCOL_VERSION = "2024-11-05"

      def initialize(command:, args: [], env: {})
        @command = command
        @args = args
        @env = env
        @next_id = 0
      end

      def start
        @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(@env, @command, *@args)
        @stdin.sync = true
        send_handshake
        self
      end

      def stop
        return unless @stdin
        @stdin.close rescue nil
        @stdout.close rescue nil
        @stderr.close rescue nil
        @wait_thread.kill if @wait_thread&.alive?
        @stdin = @stdout = @stderr = @wait_thread = nil
      end

      def list_tools
        resp = send_request("tools/list", {})
        (resp["tools"] || []).map do |t|
          {
            name: t["name"],
            description: t["description"],
            input_schema: t["inputSchema"]
          }
        end
      end

      def call_tool(name, arguments)
        resp = send_request("tools/call", { name: name, arguments: arguments })
        {
          content: (resp["content"] || []).map { |c| c.transform_keys(&:to_sym) },
          is_error: resp["isError"] || false
        }
      end

      private

      def send_handshake
        send_request(
          "initialize",
          {
            protocolVersion: PROTOCOL_VERSION,
            capabilities: {},
            clientInfo: { name: "workflows-prospect", version: Workflows::VERSION }
          }
        )
        send_notification("notifications/initialized", {})
      end

      def send_notification(method, params)
        write_message({ jsonrpc: "2.0", method: method, params: params })
      end

      def send_request(method, params, timeout_s: 60)
        id = (@next_id += 1)
        write_message({ jsonrpc: "2.0", id: id, method: method, params: params })
        read_response_for(id, timeout_s: timeout_s)
      end

      def write_message(msg)
        @stdin.write(msg.to_json + "\n")
      end

      def read_response_for(id, timeout_s:)
        deadline = Time.now + timeout_s
        loop do
          raise ProtocolError, "timeout waiting for response #{id}" if Time.now > deadline
          line = @stdout.gets
          raise ProtocolError, "MCP server closed stream" if line.nil?
          msg = JSON.parse(line)
          next unless msg["id"] == id
          if msg["error"]
            raise ProtocolError, "tool error: #{msg["error"].inspect}"
          end
          return msg["result"] || {}
        end
      end
    end
  end
end
