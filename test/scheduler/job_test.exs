defmodule Scheduler.JobTest do
  use ExUnit.Case, async: true

  alias Scheduler.Job

  describe "new/1" do
    test "creates a job with default values" do
      job = Job.new(%{"name" => "test_job"})

      assert job.name == "test_job"
      assert job.status == :pending
      assert job.attempts == 0
      assert job.deps == []
      assert job.args == []
      assert job.id != nil
    end

    test "creates a job with atom keys" do
      job = Job.new(%{name: "test_job", deps: ["dep1"], args: ["arg1"]})

      assert job.name == "test_job"
      assert job.deps == ["dep1"]
      assert job.args == ["arg1"]
    end

    test "sets retry policy from attributes" do
      job = Job.new(%{
        "name" => "retry_job",
        "retry_policy" => %{"max_retries" => 3, "backoff_ms" => 2000}
      })

      assert job.max_retries == 3
      assert job.backoff_ms == 2000
    end

    test "defaults to 0 retries and 1000ms backoff" do
      job = Job.new(%{"name" => "no_retry"})

      assert job.max_retries == 0
      assert job.backoff_ms == 1000
    end
  end

  describe "transition/2" do
    test "allows pending -> running" do
      job = Job.new(%{"name" => "test"})
      assert {:ok, updated} = Job.transition(job, :running)
      assert updated.status == :running
      assert updated.started_at != nil
    end

    test "allows running -> completed" do
      job = %{Job.new(%{"name" => "test"}) | status: :running}
      assert {:ok, updated} = Job.transition(job, :completed)
      assert updated.status == :completed
      assert updated.completed_at != nil
    end

    test "allows running -> retrying" do
      job = %{Job.new(%{"name" => "test"}) | status: :running}
      assert {:ok, updated} = Job.transition(job, :retrying)
      assert updated.status == :retrying
    end

    test "allows running -> failed" do
      job = %{Job.new(%{"name" => "test"}) | status: :running}
      assert {:ok, updated} = Job.transition(job, :failed)
      assert updated.status == :failed
    end

    test "allows retrying -> running" do
      job = %{Job.new(%{"name" => "test"}) | status: :retrying}
      assert {:ok, updated} = Job.transition(job, :running)
      assert updated.status == :running
    end

    test "rejects invalid transitions" do
      job = Job.new(%{"name" => "test"})
      assert {:error, _} = Job.transition(job, :completed)
    end

    test "rejects invalid status" do
      job = Job.new(%{"name" => "test"})
      assert {:error, _} = Job.transition(job, :unknown)
    end
  end

  describe "additional transitions" do
    test "allows pending -> failed" do
      job = Job.new(%{"name" => "test"})
      assert {:ok, updated} = Job.transition(job, :failed)
      assert updated.status == :failed
      assert updated.completed_at != nil
    end

    test "allows retrying -> failed" do
      job = %{Job.new(%{"name" => "test"}) | status: :retrying}
      assert {:ok, updated} = Job.transition(job, :failed)
      assert updated.status == :failed
    end

    test "allows failed -> pending" do
      job = %{Job.new(%{"name" => "test"}) | status: :failed}
      assert {:ok, updated} = Job.transition(job, :pending)
      assert updated.status == :pending
    end

    test "allows completed -> pending" do
      job = %{Job.new(%{"name" => "test"}) | status: :completed}
      assert {:ok, updated} = Job.transition(job, :pending)
      assert updated.status == :pending
    end

    test "rejects completed -> running" do
      job = %{Job.new(%{"name" => "test"}) | status: :completed}
      assert {:error, _} = Job.transition(job, :running)
    end
  end

  describe "valid_states/0" do
    test "returns all valid states" do
      states = Job.valid_states()
      assert :pending in states
      assert :running in states
      assert :completed in states
      assert :failed in states
      assert :retrying in states
    end
  end

  describe "new/1 with retry_policy atom keys" do
    test "sets max_retries and backoff_ms from atom-keyed policy" do
      job = Job.new(%{name: "r", retry_policy: %{max_retries: 5, backoff_ms: 500}})
      assert job.max_retries == 5
      assert job.backoff_ms == 500
    end

    test "generates an id when not provided" do
      job = Job.new(%{name: "auto_id"})
      assert job.id != nil
      assert byte_size(job.id) > 0
    end
  end
end
