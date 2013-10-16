# -*- coding: utf-8 -*-
module SpoAuthModule
  extend ActiveSupport::Concern

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
  module ClassMethods
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
  end
end
