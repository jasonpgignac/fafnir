class SmsComputerGroup < ActiveWmi::Base
  
  self.site = "winmgmts:\\\\oldtas247\\root\\sms\\site_100"
  self.user = "ugignja"
  self.password = "M0xMcMaherty"
  self.element_name = "SMS_Collection"
  self.set_primary_key "CollectionID"
  
end