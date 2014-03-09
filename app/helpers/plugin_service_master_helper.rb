module PluginServiceMasterHelper

  def generate_td_attr sched
    attributes = 'class="sched" '

    # Change <td> class depending on activity
    if sched.present? && sched.sch_wg5.present?
      case sched.sch_wg5
        when 2 
          attributes = 'class="sched projectwork"' 
        when 3 
          attributes = 'class="sched housekeeping"' 
        when 4 
          attributes = 'class="sched daycleaning"' 
        when 5 
          attributes = 'class="sched supervision"'
      end 
    end

    # Add extra attributes to hold sched properties
    if sched.present?
      attributes +=
      "schid='#{ sched.id }' 
       filekey='#{ sched.filekey }' 
       date='#{ sched.sch_date }'
       starttime='#{ sched.sch_start_time.strftime('%-l:%M %p') }'
       endtime='#{ sched.sch_end_time.strftime('%-l:%M %p') }'
       cust='#{ sched.sch_wg3 }'
       activity='#{ sched.sch_wg5 }'"
    else
      attributes +=
      "schid filekey date starttime endtime cust activity"   
    end

    attributes
  end

  def generate_td_content sched
    if sched.present? && sched.id.present?
      if sched.sch_start_time.hour > 12
        "#{ sched.sch_start_time.strftime('%-l:%M %P') } -
         #{ sched.sch_end_time.strftime('%-l:%M %P') }"
      else
        "#{ sched.sch_start_time.strftime('%-l:%M') } -
         #{ sched.sch_end_time.strftime('%-l:%M') }"
      end
      
    end
  end

end
