# frozen_string_literal: true

class GitService
  module Exec
    class ExecutionError < StandardError
      attr_reader :stdout, :stderr, :status, :cmd, :env

      def initialize(status, stdout, stderr, cmd, env)
        super("Process #{cmd.split.first} exited with status #{status}: #{stdout}\n#{stderr}")
        @status = status
        @stdout = stdout
        @stderr = stderr
        @cmd = cmd
        @env = env
      end
    end

    module_function

    def exec2(cmd, **options)
      out_reader, out_writer = IO.pipe
      err_reader, err_writer = IO.pipe

      env = (options.delete(:env) || {}).to_h { |*a| a.map(&:to_s) }
      options.delete(:chdir) if options.fetch(:chdir, nil).nil?

      opts = {
        unsetenv_others: true,
        out: out_writer.fileno,
        err: err_writer.fileno
      }.merge options
      pid = Process.spawn(env, cmd, **opts)

      mut = Mutex.new
      cond = ConditionVariable.new

      status = nil
      Thread.new do
        _pid, status = Process.wait2(pid)
        mut.synchronize { cond.signal }
      end

      out_writer.close
      err_writer.close

      stdout = nil
      stderr = nil
      out_thread = Thread.new { stdout = out_reader.read }
      err_thread = Thread.new { stderr = err_reader.read }
      mut.synchronize { cond.wait(mut, 0.1) } while status.nil?

      out_thread.join
      err_thread.join

      out_reader.close
      err_writer.close
      err_reader.close

      raise ExecutionError.new(status.exitstatus, stdout, stderr, cmd, env) unless status.success?

      [stdout, stderr]
    end

    def exec(cmd, **options) = exec2(cmd, **options).first
  end
end
