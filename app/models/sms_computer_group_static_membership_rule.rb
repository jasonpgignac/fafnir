class SmsComputerGroupStaticMembershipRule < ActiveWmi::Base
  
  self.site = "winmgmts:\\\\oldtas247\\root\\sms\\site_100"
  self.user = "ugignja"
  self.password = "M0xMcMaherty"
  self.element_name = "SMS_CollectionRuleDirect"
  self.set_primary_keys "CollectionID", "RuleName"
  
end