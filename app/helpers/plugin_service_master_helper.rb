module PluginServiceMasterHelper

  def generate_td_attr sched
    attributes = "class='sched"
    
    # If this <td> has a schedule
    if sched.present?

      # Change <td> class depending on activity
      if sched.sch_wg5.present?
        case sched.sch_wg5
          when 2 
            attributes += " projectwork"
          when 3 
            attributes += " housekeeping"
          when 4 
            attributes += " daycleaning"
          when 5 
            attributes += " supervision"
        end 
      end

      # Add extra class if this is an overlapping sched
      if sched.overlapping.present?
        attributes += " overlap"
      end

      # Add extra attributes to hold sched properties      
      attributes +=
        "' schid='#{ sched.id }' 
         filekey='#{ sched.filekey }' 
         date='#{ sched.sch_date }'
         starttime='#{ sched.sch_start_time.strftime('%-l:%M %P') }'
         endtime='#{ sched.sch_end_time.strftime('%-l:%M %P') }'
         cust='#{ sched.sch_wg3 }'
         team='#{ sched.sch_wg8 }'
         activity='#{ sched.sch_wg5 }'
         title='#{ sched.sch_hours_hund.to_f.round(2) } hours'"
    else
      attributes +=
      "' schid filekey date starttime endtime cust team activity"
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
