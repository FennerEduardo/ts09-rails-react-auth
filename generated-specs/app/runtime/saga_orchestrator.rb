# frozen_string_literal: true

# Orchestrated saga: progress is persisted after every step; when a step fails, the completed steps
# are compensated in reverse order. Re-running a saga id resumes after its completed steps.
class SagaOrchestrator
  Step = Struct.new(:name, :action, :compensate)

  def initialize(database_url, schema = "public")
    @database_url = database_url
    @s = RuntimeSchema.name_for(schema)
  end

  def run(saga_id, tenant_id, steps)
    conn = PG.connect(@database_url)
    conn.exec_params("INSERT INTO #{@s}.ghk_sagas (id, tenant_id, status) VALUES ($1, $2, 'RUNNING') ON CONFLICT (id) DO NOTHING", [saga_id, tenant_id])
    done = conn.exec_params("SELECT completed_steps FROM #{@s}.ghk_sagas WHERE id = $1 AND tenant_id = $2", [saga_id, tenant_id]).first&.fetch("completed_steps").to_s
    completed = done.empty? ? [] : done.split(",")
    steps.each do |step|
      next if completed.include?(step.name)

      begin
        step.action.call
      rescue StandardError
        save(conn, saga_id, "COMPENSATING", completed)
        completed.reverse.each do |name|
          steps.find { |s| s.name == name }.compensate.call
          completed.delete(name)
          save(conn, saga_id, "COMPENSATING", completed)
        end
        save(conn, saga_id, "COMPENSATED", completed)
        return "COMPENSATED"
      end
      completed << step.name
      save(conn, saga_id, "RUNNING", completed)
    end
    save(conn, saga_id, "COMPLETED", completed)
    "COMPLETED"
  ensure
    conn&.close
  end

  def status(saga_id)
    conn = PG.connect(@database_url)
    row = conn.exec_params("SELECT status, completed_steps FROM #{@s}.ghk_sagas WHERE id = $1", [saga_id]).first
    row && { status: row["status"], completed_steps: row["completed_steps"].empty? ? [] : row["completed_steps"].split(",") }
  ensure
    conn&.close
  end

  private

  def save(conn, saga_id, status, completed)
    conn.exec_params("UPDATE #{@s}.ghk_sagas SET status = $2, completed_steps = $3, updated_at = now() WHERE id = $1", [saga_id, status, completed.join(",")])
  end
end
