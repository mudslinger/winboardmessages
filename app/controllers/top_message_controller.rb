# coding: utf-8
class TopMessageController < ApplicationController

  layout "blank"
  around_filter :iframe_ref_auth, :only => :message

  def message
    @type = params[:type] if present?
    @key = 0
    @key = params[:key].to_i if present?

    list = nil
    cache_key = [@type,@key].join('#')
    begin
      list = Redis.current.lrange(@type,(@key == 0 ? 0 : @key-1),@key+1).map{ |item|
        OpenStruct.new(MessagePack.unpack(item)).extend(Message)
      }
      Rails.cache.write(cache_key,list,:expires_in => 10.minutes) unless Rails.cache.read(cache_key)
    rescue
      list = Rails.cache.read(cache_key)
    ensure
      @entry = @key == 0 ? list[0] : list[1]
      @prev_entry = @key == 0 ? nil : list[0]
      @next_entry = @key == 0 ? list[1] : list[2]
    end
  end

  private
    def iframe_ref_auth
      response.headers["X-Frame-Options"] = 'Allow-From http://ec9.winboard.jp/ https://ec9.winboard.jp/'

      referer = request.referer
      referer = '' unless referer.present?

      #リファラー無しの場合はforbidden
      # if (
      #     referer.include?('ec9.winboard') ||
      #     referer.include?('192.168') ||
      #     referer.include?('yamaokaya')
      #   ) then
      #   yield
      # else
      #   render :status => :forbidden, :text => "Forbidden"
      # end
      yield
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
