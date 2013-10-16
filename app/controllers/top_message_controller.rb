class TopMessageController < ApplicationController

  layout "blank"

  def message
    @type = params[:type] if present?
    @key = 0
    @key = params[:key].to_i if present?
    list = Redis.current.lrange(@type,(@key == 0 ? 0 : @key-1),@key+1).map{ |item|
      OpenStruct.new(MessagePack.unpack(item)).extend(Message)
    }
    @entry = @key == 0 ? list[0] : list[1]
    @prev_entry = @key == 0 ? nil : list[0]
    @next_entry = @key == 0 ? list[1] : list[2]
  end

  def x
    SpoSyncWorker.new.perform()
  end
end

module Message
  def new?
    Time.at(self.local_updated_at) > 3.days.ago
  end

  def updated_at
    Time.at(self.local_updated_at)
  end

  def icon
    case self.entry_type
      when "Microsoft.SharePoint.DataService.社長メッセージItem"
        "wb/ymticon.png"
      when "Microsoft.SharePoint.DataService.専務メッセージItem"
        "wb/144icon.png"
      when "Microsoft.SharePoint.DataService.連絡通達Item"
        "wb/hqicon.png"
    end
  end

  def src_uri
    "https://yamaokaya1.sharepoint.com/Lists/#{self.src_type}/DispForm.aspx?ID=#{self.local_id}"
  end

  def src_type
    case self.entry_type
      when "Microsoft.SharePoint.DataService.社長メッセージItem"
        "President"
      when "Microsoft.SharePoint.DataService.専務メッセージItem"
        "Md144"
      when "Microsoft.SharePoint.DataService.連絡通達Item"
        "Notify"
    end
  end
end
