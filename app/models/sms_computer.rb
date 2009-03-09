class SmsComputer < ActiveWmi::Base
  
  self.site = "winmgmts:\\\\oldtas247\\root\\sms\\site_100"
  self.user = "ugignja"
  self.password = "M0xMcMaherty"
  self.element_name = "SMS_R_System"
  self.set_primary_key "ResourceID"
  
  RAILS_TO_SMS_MAPPING = {
    :name       => 'Name',
    :user       => 'LastLogonUsername',
    :remote_id  => 'ResourceID',
    :addresses  => 'IPAddresses',
    :domain     => 'ResourceDomainOrWorkgroup'
  }
  
  def self.test_search 
    self.find(:all, :params => {:lastlogonusername => "umartar"})
  end
  
end
