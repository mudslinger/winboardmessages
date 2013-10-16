class SpoSyncWorker
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  #sidekiq_options queue: :event
  sidekiq_options retry: false

  recurrence { minutely(33) }

  AUTHXML = <<"HERE"
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:a="http://www.w3.org/2005/08/addressing" xmlns:u="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
  <s:Header>
    <a:Action s:mustUnderstand="1">http://schemas.xmlsoap.org/ws/2005/02/trust/RST/Issue</a:Action>
    <a:ReplyTo>
      <a:Address>http://www.w3.org/2005/08/addressing/anonymous</a:Address>
    </a:ReplyTo>
    <a:To s:mustUnderstand="1">https://login.microsoftonline.com/extSTS.srf</a:To>
    <o:Security s:mustUnderstand="1" xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
      <o:UsernameToken>
        <o:Username>bpos-admin@yamaokaya.jp</o:Username>
        <o:Password>P@ssw0rd</o:Password>
      </o:UsernameToken>
    </o:Security>
  </s:Header>
  <s:Body>
    <t:RequestSecurityToken xmlns:t="http://schemas.xmlsoap.org/ws/2005/02/trust">
      <wsp:AppliesTo xmlns:wsp="http://schemas.xmlsoap.org/ws/2004/09/policy">
        <a:EndpointReference>
          <a:Address>https://yamaokaya1.sharepoint.com/</a:Address>
        </a:EndpointReference>
      </wsp:AppliesTo>
      <t:KeyType>http://schemas.xmlsoap.org/ws/2005/05/identity/NoProofKey</t:KeyType>
      <t:RequestType>http://schemas.xmlsoap.org/ws/2005/02/trust/Issue</t:RequestType>
      <t:TokenType>urn:oasis:names:tc:SAML:1.0:assertion</t:TokenType>
    </t:RequestSecurityToken>
  </s:Body>
</s:Envelope>
HERE
  @@types = {
    "Microsoft.SharePoint.DataService.社長メッセージItem" => {
      type: "president",
      uri: "https://yamaokaya1.sharepoint.com/_vti_bin/listdata.svc/社長メッセージ()"
    },
    "Microsoft.SharePoint.DataService.専務メッセージItem" => {
      type: "md144",
      uri: "https://yamaokaya1.sharepoint.com/_vti_bin/listdata.svc/専務メッセージ()"
    },
    "Microsoft.SharePoint.DataService.連絡通達Item" => {
      type: "notice",
      uri: "https://yamaokaya1.sharepoint.com/_vti_bin/listdata.svc/連絡通達()"
    }
  }.freeze

  def perform
    cookies = getSPOCookies
    @@types.each_value do |type|
      Redis.current.del type[:type]
      load(type[:uri],cookies).reverse.each{|e| Redis.current.rpush(type[:type],e.to_msgpack)}
      log('spo.message.loaded',type)
    end

  end

  private
  def load(uri,cookies)
    json = RestClient.get(
      URI::encode(uri),
      {
        :accept => "application/json",
        :Cookie => cookies
      }
    )
    jsons = JSON.parse(json)["d"]["results"]
    #取得したデータを登録
    list = []
    jsons.each do |j|
      type = j["__metadata"]["type"]
      local_id = j['ID']
      j["作成日時"] =~ /\/Date\(([0-9]+)\)\//
      local_created_at = ($1.to_i / 1000)
      j["更新日時"] =~ /\/Date\(([0-9]+)\)\//
      local_updated_at = ($1.to_i / 1000)

      e = {
        original_url: j["__metadata"]["uri"],
        entry_type: j["__metadata"]["type"],
        title: j["タイトル"],
        body: j["本文"],
        local_created_at: local_created_at,
        local_updated_at: local_updated_at,
        local_id: j['ID']
      }

      doc = Nokogiri::HTML(e[:body])
      #Aタグのリンク先の置き換えを行う
      doc.search('a').each do |node|
        node['href'] = 'https://yamaokaya1.sharepoint.com' + node['href'] if node['href'] =~ /^\/.+/
        node['target'] = "_blank"
      end
      #IMGタグのURLの置き換えを行う
      doc.search('img').each do |node|
        node['src'] = 'https://yamaokaya1.sharepoint.com' + node['src'] if node['src']  =~ /^\/.+/
      end
      e[:body] = doc.css("html body").inner_html
      list << e
    end
    return list
  end

  def getSPOCookies
    #tokenをゲット
    xml = RestClient.post(
      "https://login.microsoftonline.com/extSTS.srf",
      AUTHXML,
      :content_type => "application/x-www-form-urlencoded",
      :user_agent => 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Win64; x64; Trident/5.0)'
    )
    ActiveSupport::XmlMini.backend = 'Nokogiri'
    doc = ActiveSupport::XmlMini.parse(xml)
    token = doc['Envelope']['Body']['RequestSecurityTokenResponse']['RequestedSecurityToken']['BinarySecurityToken']['__content__']
    #tokenをキーにしてクッキーをゲット
    RestClient.post(
      "https://yamaokaya1.sharepoint.com/_forms/default.aspx?wa=wsignin1.0",
      token,
      {
        :content_type => "application/x-www-form-urlencoded",
        :user_agent => 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Win64; x64; Trident/5.0)'
      }
    ){ |response, request, result|
      if [301, 302, 307].include? response.code
        str = ""
        response.headers[:set_cookie].each do |s|
          str << s << "; " if s =~ /^FedAuth/
          str << s << "; " if s =~ /^rtFa/
        end
        return str
      end
    }
  end

  def log(tag,obj)
    begin
      Fluent::Logger::FluentLogger.open(
        FLUENT_CONFIG[:tag],
        host: FLUENT_CONFIG[:host],
        port: FLUENT_CONFIG[:port]
      )
      Fluent::Logger.post(tag,obj)
    end
  end
end