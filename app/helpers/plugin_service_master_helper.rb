module PluginServiceMasterHelper

  def generate_td_attr sched
    if sched.nil?
      "filekey date starttime endtime cust activity"
    else
      "filekey='#{ sched.filekey }' 
      date='#{ sched.sch_date }'
      starttime='#{ sched.sch_start_time.strftime('%-I:%M') }'
      endtime='#{ sched.sch_end_time.strftime('%-I:%M') }'
      cust='#{ sched.sch_wg3 }'
      activity='#{ sched.sch_wg5 }'"
    end
  end

  def generate_td_content sched
    if sched.present?
      "#{ sched.sch_start_time.strftime('%-I:%M') } -
      #{ sched.sch_end_time.strftime('%-I:%M') }"
    end
  end

end
