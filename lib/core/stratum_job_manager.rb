# -*- encoding : utf-8 -*-

require_relative "./stratum_job"

class StratumJobManager
  def initialize
    @jobs = {}
    @id_ctr = "000a"
    @job_ids_removed = []
  end

  # => job or raise
  def add_job( job, pdiff=nil )
    raise "A job with this id already exist !" if @jobs[job.id]
    job.pdiff = pdiff if pdiff
    @jobs[job.id] = job
  end

  # => job
  def new_from_ary( ary )
    ary.unshift( @id_ctr.next! ) if ary.size < 9 || ary[-1].kind_of?( Numeric )
    job = StratumJob.new *ary
    add_job( job )
  end

  # => job or nil
  def find( job_id )
    @jobs[job_id]
  end

  # => job or raise
  def find!( job_id )
    find( job_id ) || raise( "Cannot find a job with id=#{job_id.inspect}. #{@job_ids_removed.include?(job_id) ? 'Removed.' : ''}" )
  end

  def clean_before( limit )
    @jobs.delete_if do |_, job|
      job.created_at < limit && (@job_ids_removed << job.id)
    end
  end
end
